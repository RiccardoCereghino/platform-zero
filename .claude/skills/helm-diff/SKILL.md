---
name: helm-diff
description: Run helmfile diff to preview platform changes before applying
disable-model-invocation: true
---

# Helmfile Diff

Preview what changes Helmfile would apply to the platform services.

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
