# SOPS + age Secret Encryption

This repository uses [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) to encrypt secrets at rest in git.

## How It Works

- Secret files (`platform/*-secrets.yaml`) are SOPS-encrypted in git
- Only `stringData` and `data` values are encrypted; keys and metadata stay readable
- Local environment variables (`secrets/local.env.yaml`) are also SOPS-encrypted
- The `.sops.yaml` at the repo root configures which files are encrypted and with which age key
- Decryption requires the age private key

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

The age public key is in `.sops.yaml`. The private key is stored in:

1. **Kubernetes Secret** — provisioned via Terraform (`infrastructure/sops.tf`) as a Talos inline manifest in the `argocd` namespace. Mounted into the ArgoCD repo-server for KSOPS decryption at sync time.

2. **GitHub Actions secret** — `SOPS_AGE_KEY`, used by the CI/CD Infrastructure workflow for `tofu plan/apply`.

3. **Vaultwarden** (`vault.cereghino.me`) — stored as a secure note for disaster recovery and human access.

4. **Local** — set via `secrets/local.env.yaml` (self-bootstrapping: the file contains `SOPS_AGE_KEY`).

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
for f in platform/*-secrets.yaml secrets/*.yaml; do
  sops --decrypt --in-place "$f"
done

export SOPS_AGE_KEY="<new-private-key>"
for f in platform/*-secrets.yaml secrets/*.yaml; do
  sops --encrypt --in-place "$f"
done
```

Store the new private key in:
- Vaultwarden (replace the existing secure note)
- `terraform.tfvars` or `TF_VAR_sops_age_private_key` env var (Terraform reprovisions the K8s Secret)
- GitHub Actions secret (`SOPS_AGE_KEY`)
- `secrets/local.env.yaml` (re-encrypt with new key)

## Local Development

### Setup (Replaces direnv + 1Password)

```bash
# 1. Create secrets/local.env.yaml with your actual values (see template below)
# 2. Encrypt it
sops --encrypt --in-place secrets/local.env.yaml
# 3. Load into your shell
source scripts/env.sh
```

### Template for `secrets/local.env.yaml`

```yaml
HCLOUD_TOKEN: <your-hcloud-token>
TF_VAR_hcloud_token: <same-as-HCLOUD_TOKEN>
AWS_ACCESS_KEY_ID: <your-s3-access-key>
AWS_SECRET_ACCESS_KEY: <your-s3-secret-key>
TF_VAR_talos_backup_s3_access_key: <same-as-AWS_ACCESS_KEY_ID>
TF_VAR_talos_backup_s3_secret_key: <same-as-AWS_SECRET_ACCESS_KEY>
TF_VAR_hcloud_csi_encryption_passphrase: <your-csi-passphrase>
TF_VAR_sops_age_private_key: <your-age-private-key>
SOPS_AGE_KEY: <your-age-private-key>
```

### Daily Usage

```bash
# Load env vars before running tofu/helmfile commands
source scripts/env.sh

cd infrastructure && tofu plan
cd platform && helmfile diff
```

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
| `secrets/local.env.yaml` | Local dev environment variables (replaces `.envrc` + 1Password) |

## CI/CD Integration

### CI (Lint + Validate)

SOPS-encrypted files are valid YAML, so `yamllint`, `helmfile lint`, and `kubeconform` work without decryption.

### Infrastructure CD (`cd-infra.yaml`)

`TF_VAR_sops_age_private_key` is set from `secrets.SOPS_AGE_KEY`, which Terraform uses to provision the `sops-age-key` Kubernetes Secret via Talos inline manifest.

### Platform CD (ArgoCD + KSOPS)

Platform delivery uses a GitOps pull model via [ArgoCD](https://argo-cd.readthedocs.io/). ArgoCD runs in-cluster and reconciles the `platform/` directory automatically on every push to `master`.

SOPS-encrypted secrets are decrypted at sync time by [KSOPS](https://github.com/viaduct-ai/kustomize-sops), a kustomize exec plugin installed in the ArgoCD repo-server. The decryption flow:

1. ArgoCD detects `platform/kustomization.yaml` and runs kustomize with `--enable-alpha-plugins --enable-exec`.
2. Kustomize invokes the KSOPS generator (`platform/ksops-generator.yaml`), which lists all `*-secrets.yaml` files.
3. KSOPS decrypts the secrets using its embedded SOPS library with the age key mounted from the `sops-age-key` Secret in the `argocd` namespace.
4. Decrypted Secret manifests are emitted alongside the plain resources listed in `kustomization.yaml`.

The repo-server is configured via `platform/argocd-values.yaml`:
- An init container (`viaductoss/ksops:v4.3.2`) copies `ksops` and `kustomize` binaries into the repo-server. KSOPS v4+ embeds the SOPS library directly (no standalone `sops` binary needed).
- The `sops-age-key` Secret is volume-mounted at `/.config/sops/age/keys.txt`.
- `SOPS_AGE_KEY_FILE` env var points to the mounted key.

Individual platform components (Helm releases and raw manifests) are defined as ArgoCD Application resources in `platform/argocd-apps/`.

## Disaster Recovery

If the age private key is lost:

1. Check Vaultwarden (`vault.cereghino.me`) for the secure note containing the key
2. If Vaultwarden is also unavailable, the secrets must be recreated from their original sources (GitHub OAuth app, manually generated tokens, etc.)
3. Generate a new age keypair, update `.sops.yaml`, and re-encrypt all secret files
4. Update the Kubernetes Secret (via Terraform), GitHub Actions secret, and `secrets/local.env.yaml`
