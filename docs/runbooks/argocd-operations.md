# Runbook: ArgoCD Operations

**Target System:** ArgoCD
**Author(s):** Riccardo Cereghino
**Last Updated:** 2026-03-14

## Objective
Manage ArgoCD applications, sync states, and troubleshoot deployment issues in the App-of-Apps platform pattern.

## Prerequisites
* access to `platform` directory in the repository
* `kubectl` CLI installed and authenticated
* `helmfile` CLI installed
* `sops` CLI installed and Age private key configured

## Execution Steps

### Bootstrapping ArgoCD
ArgoCD itself is deployed via Helmfile (not self-managed), because it needs to exist before it can manage anything.
```bash
cd platform
helmfile apply --selector name=argocd
```
Then bootstrap the root Application:
```bash
kubectl apply -f platform/argocd-apps/platform-manifests.yaml
```
This single apply kicks off the entire App-of-Apps cascade.

### Adding a New Application
1. Create the ArgoCD Application manifest in `platform/argocd-apps/<name>.yaml`
2. If Helm-based, add the release to `platform/helmfile.yaml` (for lint reference) and define `valuesObject` inline in the Application manifest
3. Add any required namespace or HTTPRoute manifests to `platform/`
4. Register everything in `platform/kustomization.yaml`
5. Push to `master` — ArgoCD auto-syncs via `platform-manifests`

### Disabling an Application
Comment out entries in `platform/kustomization.yaml`. ArgoCD's auto-prune removes the Application and cascades deletion to its resources. Files stay in the repo for re-enablement.
Example:
```yaml
# - argocd-apps/longhorn.yaml  # Disabled — see ADR-031
```
To re-enable, uncomment and push to master.

### Emergency: Out-of-Band Application Apply
If an Application needs to be applied outside the normal GitOps flow:
```bash
kubectl apply -f platform/argocd-apps/<name>.yaml
```
This is a temporary override — ArgoCD will reconcile it back to the git state on next sync.

### Forcing a Sync
Via CLI:
```bash
argocd app sync <app-name>
```
Via kubectl (trigger a refresh):
```bash
kubectl annotate application <app-name> -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

## Validation
* Access the ArgoCD UI via URL `https://argocd.cereghino.me` using SSO via Dex (GitHub OIDC)
* Verify that Applications show a "Synced" and "Healthy" status in the UI or via CLI: `argocd app get <app-name>`

## Troubleshooting
* **Error:** Application Stuck in "Progressing"
  * **Cause:** Common causes include missing CRDs (sync waves needed), resource quotas, or image pull errors.
  * **Fix:** Check the application status:
    ```bash
    kubectl get application <name> -n argocd -o yaml | grep -A 20 status
    ```
* **Error:** KSOPS Decryption Failures
  * **Cause:** The `sops-age-key` Secret might be missing in the `argocd` namespace.
  * **Fix:** Check if it exists:
    ```bash
    kubectl get secret sops-age-key -n argocd
    ```
    If absent, re-apply infrastructure: `cd infrastructure && tofu apply`

## Rollback Procedure
* For application changes (Adding/Disabling): Revert the commit in Git and push to `master`. ArgoCD will automatically sync back to the previous state.
* For emergency out-of-band applies: Trigger a sync from ArgoCD to reconcile the application back to the state defined in Git.
