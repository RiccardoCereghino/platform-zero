# Runbook: Secrets Management

**Target System:** SOPS
**Author(s):** Riccardo Cereghino
**Last Updated:** 2026-03-14

## Objective
Manage and encrypt/decrypt secrets for both local development and the cluster platform layer using SOPS.

## Prerequisites
* `sops` CLI installed
* Age private key installed at `~/.config/sops/age/keys.txt`
* `.sops.yaml` configuration at the repository root defining encryption rules

## Execution Steps

### Local Development Secrets
Local secrets (Hetzner API token, AWS credentials, etc.) are stored in `secrets/local.env.yaml`, encrypted with SOPS.

1. **Loading Secrets into Shell:**
   ```bash
   source scripts/env.sh
   ```
   This decrypts `secrets/local.env.yaml` and exports the variables into your current shell. Required before running `tofu plan/apply` or `helmfile` commands locally.

2. **Editing Local Secrets:**
   ```bash
   sops secrets/local.env.yaml
   ```
   Opens in your editor, decrypted. Re-encrypts on save.

> Note: For first-time setup, see `SOPS.md` at the repo root for age key generation and initial configuration.

### Cluster Secrets (Platform Layer)
Cluster secrets (`platform/*-secrets.yaml`) are SOPS-encrypted in git and decrypted at sync time by KSOPS in the ArgoCD repo-server.

1. **Adding a New Cluster Secret:**
   1. Create the Secret YAML with plaintext values
   2. Encrypt in place: `sops -e -i platform/<name>-secrets.yaml`
   3. Add a generator entry in `platform/ksops-generator.yaml`
   4. Reference in `platform/kustomization.yaml` if needed
   5. Commit and push

2. **Editing a Cluster Secret:**
   ```bash
   sops platform/<name>-secrets.yaml
   ```
   Commit and push — ArgoCD auto-syncs the decrypted Secret into the cluster.

## Validation
* For local secrets: Run `env | grep <SECRET_KEY>` to verify that it's successfully exported to your shell after sourcing `env.sh`.
* For cluster secrets: Verify in the ArgoCD UI that the secret is synced correctly without any KSOPS decryption errors, or verify against the cluster directly using `kubectl get secret <secret_name> -n <namespace>`.

## Troubleshooting
* **Error:** ArgoCD fails to sync App with KSOPS Decryption Failures
  * **Cause:** KSOPS Decryption Chain failure. ArgoCD repo-server has an init container that provides `ksops` and `kustomize` binaries. The `sops-age-key` Secret in the `argocd` namespace supplies the decryption key. If this Secret is missing, all KSOPS-managed secrets fail to decrypt.
  * **Fix:** Verify the secret exists: `kubectl get secret sops-age-key -n argocd`. Re-apply infrastructure if missing via `cd infrastructure && tofu apply`.
* **Error:** Unable to open or decrypt SOPS file locally (`Failed to get the data key required to decrypt`)
  * **Cause:** Missing or incorrect age private key.
  * **Fix:** Ensure your age private key `keys.txt` is located in `~/.config/sops/age/keys.txt` and matches the public recipient defined in `.sops.yaml`.

## Rollback Procedure
* For local secrets modifications: Check out the previous commit version of the file and push if in Git. For local edits, restore the previous contents and save the file via `sops` again.
* For cluster secrets modifications: Revert the git commit where the secret was changed and push to `master`. ArgoCD will synchronize to the original state.
