# ADR-031: Disable Longhorn, Backstage, and Crossplane

**Date:** 2026-03-14
**Status:** Accepted
**Author(s):** Riccardo Cereghino

## Context
Three platform components — Longhorn, Backstage, and Crossplane (including its providers) — were deployed as ArgoCD Applications but are not providing value in the current cluster state. Running partially configured services wastes cluster resources and adds operational noise without benefit.

- **Longhorn** was deployed as a secondary distributed storage layer alongside Hetzner CSI. All production workloads (Vaultwarden, CNPG) use Hetzner CSI storage classes (`vault-storage`, `hcloud-volumes-encrypted`). Longhorn was configured with `defaultClass: false` and has no consumers. Running it adds unnecessary resource consumption (DaemonSet on every node, manager pods, engine/replica processes) with no benefit.

- **Backstage** (ADR-028) was deployed as a placeholder for the developer portal vision. No Software Templates, catalog entities, or plugins are configured. It is consuming resources (Node.js application) without serving any developer workflows.

- **Crossplane** (ADR-027) was deployed with providers for Kubernetes, Helm, AWS, and Hetzner Cloud. The providers are in a degraded state and no Compositions or Managed Resources are active. Bringing it back to operational state requires a dedicated deep-dive into provider configuration, credential management, and XRD/Composition authoring.

## Decision
Disable all three components by commenting out their references in `platform/kustomization.yaml`. The ArgoCD Application manifests, Helmfile release definitions, namespace manifests, and HTTPRoute files are preserved in the repository for future re-enablement.

## Rationale

## Consequences
- Reduced cluster resource consumption (Longhorn DaemonSet, Backstage pod, Crossplane controllers + provider pods).
- Cleaner ArgoCD dashboard showing only actively used applications.
- No impact on Vaultwarden or any other workload — all persistent storage uses Hetzner CSI, not Longhorn.
- Crossplane CRDs will be removed when the Application is pruned; if any Managed Resources existed they would be orphaned. No Managed Resources currently exist.
- Re-enabling any component requires uncommenting lines in `kustomization.yaml` and pushing to master. ArgoCD will auto-sync.
