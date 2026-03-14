# Runbook: Infrastructure Deployment

**Target System:** OpenTofu / Infrastructure Automation
**Author(s):** Riccardo Cereghino
**Last Updated:** 2026-03-14

## Objective
Deploy changes to the infrastructure layer (`infrastructure/`) automatically via GitHub Actions or apply targeted changes manually.

## Prerequisites
* access to `infrastructure` directory in the repository
* `tofu` CLI installed
* `sops` CLI installed and Age private key configured
* Available local secrets in `secrets/local.env.yaml`

## Execution Steps

### 1. Day-2 Changes (GitOps Flow)
1. Create a branch and modify `infrastructure/*.tf` files.
2. Push the branch and open a Pull Request. CI will automatically run validation checks.
3. Review the `tofu plan` output generated in the PR checks.
4. Merge to `master` — CD automatically applies the planned changes.

### 2. CI Validation (Local)
Validation runs automatically on PR, but can be executed locally:
```bash
cd infrastructure
tofu fmt -check       # Formatting
tofu validate         # Config validation
# Note: planning requires sourcing secrets first via scripts/env.sh
tofu plan             # Dry-run
```

### 3. Targeted Manual Apply
For situations where a targeted apply is needed without touching other resources (e.g. emergency fixes):
```bash
cd infrastructure
source ../scripts/env.sh
tofu apply -target='<resource_address>'
```

## Validation
* For automated pipelines: Verify the GitHub Actions CD run on the `master` branch is green and completed successfully. Check the pipeline logs for the `Apply complete!` message.
* For local targeted applies: Verify the output ends with `Apply complete!` and the infrastructure reflects the expected state.

## Troubleshooting
* **Error:** `Error: Error acquiring the state lock`
  * **Cause:** Another process is holding the infrastructure lock (e.g. a previous failed CI run or concurrent plan).
  * **Fix:** Wait for the other process to finish, or manually force-unlock if absolutely certain there are no running processes: `tofu force-unlock <LOCK_ID>`.
* **Error:** Missing Required Secrets during Plan
  * **Cause:** Trying to plan locally without having sourced `local.env.yaml`.
  * **Fix:** Run `source ../scripts/env.sh` from the repo root before planning.

## Rollback Procedure
* For automated pipelines: Revert the relevant commit in git, open a new PR, review the plan which should destroy/revert changes, and merge it. Alternatively, pin the resource to the last known working configuration in Terraform files.
* For targeted manual applies: Re-run a targeted apply pointing to the original/safe state if configuration was changed, or roll back the Terraform code manually and apply it.
