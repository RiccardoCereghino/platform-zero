# Runbook: Platform Changes

**Target System:** ArgoCD / Kubernetes Platform Layer
**Author(s):** Riccardo Cereghino
**Last Updated:** 2026-03-14

## Objective
Make day-2 changes to the platform layer (Kubernetes workloads managed via ArgoCD) using a GitOps workflow.

## Prerequisites
* access to `platform` directory in the repository
* `yamllint` CLI installed
* `helmfile` CLI installed
* `kubeconform` CLI installed
* `sops` CLI installed and Age private key configured (for secrets editing)

## Execution Steps

### 1. Create a Branch
```bash
git checkout -b <branch-name>
```

### 2. Make Changes
Platform changes typically involve one or more of:
* **Helm values**: Edit inline `valuesObject` in `platform/argocd-apps/<app>.yaml`
  * Add the helm release to `platform/helmfile.yaml` to include it in CLI linting
* **Raw manifests**: Add/edit YAML files in `platform/` (HTTPRoutes, namespaces, RBAC, CNPG clusters)
* **Secrets**: Edit SOPS-encrypted files (`platform/*-secrets.yaml`) using `sops`
  * Editing an Encrypted Secret:
    ```bash
    sops platform/dex-secrets.yaml
    ```
    This opens the decrypted file in your editor. On save, it re-encrypts automatically.
  * Creating a New Secret:
    1. Create the plaintext YAML file
    2. Encrypt it: `sops -e -i platform/<name>-secrets.yaml`
    3. Add a KSOPS generator entry in `platform/ksops-generator.yaml`
    4. Reference the generated Secret in `platform/kustomization.yaml`
* **Updating Helm Chart Versions**:
  1. Update `version` in the ArgoCD Application manifest (`platform/argocd-apps/<app>.yaml`)
  2. Mirror the version in `platform/helmfile.yaml` (for lint compatibility)
* **Kustomization**: Add/remove resources from `platform/kustomization.yaml`

### 3. Local Validation
```bash
# YAML linting
yamllint -c .yamllint platform/

# Helmfile lint (validates chart references and values)
cd platform && helmfile lint

# Kubeconform (validates against K8s schemas)
cd platform && helmfile template | kubeconform -strict -summary -ignore-missing-schemas
```

### 4. Commit and Push
```bash
git add <files>
git commit -m "feat/fix/docs: description of change"
git push -u origin <branch-name>
```

### 5. Review and Merge
1. Open PR and Review
2. CI runs: `yamllint`, `helmfile lint`, `kubeconform`. Review the output.
3. Merge to Master

## Validation
* ArgoCD detects the change on `master` and auto-syncs within its polling interval (default 3 minutes) or immediately if webhooks are configured.
* Verify your changes log or statuses in the ArgoCD UI (`https://argocd.cereghino.me`).

## Troubleshooting
* **Error:** CI Validation failures on PR (e.g., `helmfile lint` fails)
  * **Cause:** Formatting issue, malformed values, or missing/out-of-sync chart references in `helmfile.yaml` vs the `argocd-apps/*.yaml` file.
  * **Fix:** Run step 3 locally (`helmfile lint`, etc.) and read the specific validation output. Update your files to resolve it.

## Rollback Procedure
* Revert the merged changes from the `master` branch and push. GitOps will automatically reconcile the platform back to the reverted state.
