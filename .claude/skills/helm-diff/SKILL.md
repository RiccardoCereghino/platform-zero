---
name: helm-diff
description: Run helmfile diff to preview platform changes before applying (useful for CI validation and ArgoCD bootstrap)
disable-model-invocation: true
---

# Helmfile Diff

Preview what changes Helmfile would apply to the platform services. Note: platform deployment is handled by ArgoCD — helmfile is primarily used for CI validation and ArgoCD bootstrap.

## Steps

1. Run `helmfile diff` in the `platform/` directory:
   ```bash
   cd /Users/cerre/DevOps/platform && helmfile diff --no-color
   ```
2. If this is the first run, ensure repos are updated:
   ```bash
   cd /Users/cerre/DevOps/platform && helmfile repos && helmfile diff --no-color
   ```
3. Summarize the diff output:
   - Which releases have changes
   - What resources are added, modified, or removed in each release
   - Highlight any significant changes (image version bumps, config changes, new resources)
4. Remind the user that platform deployment is via ArgoCD. For ArgoCD itself, use `helmfile apply --selector name=argocd`. For other components, push changes to git and ArgoCD will sync.
