# SOPS + age Secret Encryption

This repository uses [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) to encrypt Kubernetes Secrets at rest in git.

## How It Works

- Secret files (`platform/*-secrets.yaml`) are SOPS-encrypted in git
- Only `stringData` and `data` values are encrypted; keys and metadata stay readable
- The `.sops.yaml` at the repo root configures which files are encrypted and with which age key
- Decryption requires the age private key (stored as a K8s Secret and in Vaultwarden)

## Prerequisites

Install `sops` and `age`:

```bash
# macOS (nix)
nix-shell -p sops age

# macOS (brew)
brew install sops age

# Ubuntu/Debian
sudo apt-get install age
# Download sops binary from https://github.com/getsops/sops/releases
```

## Key Management

### age Keypair

The age public key is in `.sops.yaml`. The private key is stored in two places:

1. **Kubernetes Secret** (for in-cluster decryption, e.g., ArgoCD KSOPS):
   ```bash
   kubectl create secret generic sops-age-key \
     --namespace=argocd \
     --from-literal=keys.txt="AGE-SECRET-KEY-..."
   ```

2. **Vaultwarden** (`vault.cereghino.me`): stored as a secure note for disaster recovery and human access.

### Generating a New Keypair

If you need to regenerate (e.g., key rotation or disaster recovery):

```bash
age-keygen -o keys.txt
# Output shows the public key, e.g.:
# Public key: age1abc...xyz
```

Update `.sops.yaml` with the new public key, then re-encrypt all secret files:

```bash
# Decrypt with the OLD key, re-encrypt with the NEW key
export SOPS_AGE_KEY="<old-private-key>"
for f in platform/*-secrets.yaml; do
  sops --decrypt --in-place "$f"
done

export SOPS_AGE_KEY="<new-private-key>"
for f in platform/*-secrets.yaml; do
  sops --encrypt --in-place "$f"
done
```

Store the new private key in:
- Vaultwarden (replace the existing secure note)
- Kubernetes Secret (`sops-age-key`)
- GitHub Actions secret (`SOPS_AGE_KEY`)

## Common Operations

### Decrypt a Secret File (View/Edit)

```bash
export SOPS_AGE_KEY="<private-key>"

# View decrypted contents
sops --decrypt platform/dex-secrets.yaml

# Edit in-place (opens $EDITOR, re-encrypts on save)
sops platform/dex-secrets.yaml
```

### Encrypt a New Secret File

1. Create the YAML file with plaintext values following the existing pattern:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: my-new-secret
     namespace: default
   type: Opaque
   stringData:
     MY_KEY: my-plaintext-value
   ```

2. Ensure the filename matches the `.sops.yaml` pattern (`platform/*-secrets.yaml`).

3. Encrypt:
   ```bash
   sops --encrypt --in-place platform/my-new-secrets.yaml
   ```

### Rotate a Secret Value

```bash
export SOPS_AGE_KEY="<private-key>"

# Opens in $EDITOR — change the value, save, and it re-encrypts automatically
sops platform/dex-secrets.yaml
```

## Encrypted Files

| File | Contents |
|------|----------|
| `platform/dex-secrets.yaml` | GitHub OAuth2 client credentials, Dex static client secret |
| `platform/vault-secrets.yaml` | Vaultwarden admin token |
| `platform/oauth2-proxy-secrets.yaml` | OAuth2 Proxy client credentials and cookie secret |
| `platform/grafana-secrets.yaml` | Grafana admin username and password |

## CI/CD Integration

### Current CI (Lint + Validate)

SOPS-encrypted files are valid YAML, so `yamllint`, `helmfile lint`, and `kubeconform` work without decryption. No changes needed for CI.

### Future Platform CD

When a platform CD workflow is added (e.g., `helmfile apply`), the CI runner will need:

1. Add `SOPS_AGE_KEY` as a GitHub Actions secret containing the age private key
2. Install sops in the workflow:
   ```yaml
   - name: Install SOPS
     run: |
       wget -qO /usr/local/bin/sops \
         https://github.com/getsops/sops/releases/download/v3.12.1/sops-v3.12.1.linux.amd64
       chmod +x /usr/local/bin/sops
   ```
3. Set the environment variable:
   ```yaml
   env:
     SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
   ```

### ArgoCD (Future)

When ArgoCD is deployed, use the [KSOPS](https://github.com/viaduct-ai/kustomize-sops) plugin to decrypt secrets during GitOps sync. The `sops-age-key` Kubernetes Secret in the `argocd` namespace provides the private key.

## Disaster Recovery

If the age private key is lost:

1. Check Vaultwarden (`vault.cereghino.me`) for the secure note containing the key
2. If Vaultwarden is also unavailable, the secrets must be recreated from their original sources (GitHub OAuth app, manually generated tokens, etc.)
3. Generate a new age keypair, update `.sops.yaml`, and re-encrypt all secret files
4. Update the Kubernetes Secret and GitHub Actions secret with the new key
