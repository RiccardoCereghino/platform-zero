---
name: tofu-plan
description: Run OpenTofu plan in the infrastructure directory and summarize changes
disable-model-invocation: true
---

# OpenTofu Plan

Run an OpenTofu plan for the infrastructure and provide a clear summary.

## Steps

1. Run `tofu plan` in the `infrastructure/` directory:
   ```bash
   cd /Users/cerre/DevOps/infrastructure && tofu plan -no-color
   ```
2. If init is needed first, run:
   ```bash
   cd /Users/cerre/DevOps/infrastructure && tofu init
   ```
3. Summarize the plan output:
   - Number of resources to add, change, and destroy
   - List each affected resource with its action
   - Highlight any destructive changes (destroys or replacements)
   - Note any warnings from the plan
