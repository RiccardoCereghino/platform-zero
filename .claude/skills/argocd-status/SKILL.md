---
name: argocd-status
description: Check the sync and health status of all ArgoCD Applications
disable-model-invocation: true
---

# ArgoCD Status

Check the status of all ArgoCD-managed platform Applications.

## Steps

1. List all ArgoCD Applications with their sync and health status:
   ```bash
   kubectl get applications -n argocd
   ```

2. If any Applications are not Synced/Healthy, get details:
   ```bash
   kubectl get applications -n argocd -o jsonpath='{range .items[?(@.status.health.status!="Healthy")]}{.metadata.name}{": "}{.status.health.status}{" - "}{.status.sync.status}{"\n"}{end}'
   ```

3. For unhealthy applications, check conditions and operation state:
   ```bash
   kubectl -n argocd get application <APP_NAME> -o jsonpath='{.status.conditions[*].message}'
   kubectl -n argocd get application <APP_NAME> -o jsonpath='{.status.operationState.phase} {.status.operationState.message}'
   ```

4. Summarize:
   - Total applications and how many are Synced/Healthy
   - List any applications with issues and their error messages
   - Suggest remediation steps for any failures
