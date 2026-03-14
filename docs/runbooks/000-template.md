# Runbook: [Task or Process Name]

**Target System:** [e.g., Kubernetes Cluster, ArgoCD, SOPS]
**Author(s):** [Name]
**Last Updated:** YYYY-MM-DD

## Objective
[What this runbook accomplishes. State the goal in one or two sentences.]

## Prerequisites
* [Tool required, e.g., `tofu` v1.6.0+]
* [Access/Credentials required]
* [Environment variables or specific working directory needed]

## Execution Steps
1. [Describe the first action clearly]
   ```bash
   # Add the exact command to run
   command --flag value
   ```
2. [Describe the next action]
   ```bash
   another-command
   ```

## Validation
[How the operator proves the execution was successful.]
* Run `[command]` and verify the output contains `[expected state]`.

## Troubleshooting
* **Error:** `[Specific error message or symptom]`
  * **Cause:** [Why this happens]
  * **Fix:** [Steps or command to resolve it]

## Rollback Procedure
[How to revert the changes if the execution fails or causes issues. If a rollback is impossible, explicitly state "N/A - Rollback not possible".]