# ADR-015: Migration from Helmfile to ArgoCD

**Date:** 2026-03-03
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

The initial platform deployment relied on `helmfile apply` executed from a local machine. This is a push-based workflow — changes only take effect when someone manually runs the command. There is no drift detection: if someone modifies a resource in-cluster via `kubectl`, the change persists silently until the next manual apply. Additionally, the upstream Terraform module was provisioning platform applications (cert-manager, Longhorn) via Talos inline manifests, creating an architectural dependency between infrastructure provisioning and application deployment.

### Alternatives Considered

- **Continuing with local `helmfile apply`** — Simple, no additional tooling, but fundamentally not GitOps. Drift goes undetected, deployments require operator presence, and there's no audit trail.
- **CI-driven push-based `kubectl apply`** — Automates deployment but still push-based. Requires storing kubeconfig credentials in CI, which is a security concern.
- **FluxCD** — Pull-based GitOps like ArgoCD, lighter weight, no UI. Strong Helm integration via HelmRelease CRDs.

## Decision

Adopt **ArgoCD** as the pull-based continuous delivery system for all platform components. Migrate platform applications away from both `helmfile apply` and Talos inline manifests into ArgoCD Application resources.

## Rationale

ArgoCD provides continuous reconciliation — it watches the Git repository and automatically synchronizes the cluster state to match. If a resource is manually altered, ArgoCD detects the drift and self-heals. It provides a visual UI showing sync status, health, and resource trees, which serves double duty as a developer-facing operations dashboard. Unlike push-based approaches, ArgoCD never needs kubeconfig credentials stored outside the cluster.

The migration moved cert-manager, Longhorn, and other platform services out of Talos inline manifests (which are tightly coupled to the infrastructure provisioning lifecycle) into ArgoCD Applications that are independently managed.

## Consequences

- Platform delivery is now pull-based: push to `master` and ArgoCD auto-syncs.
- 13 ArgoCD Application resources in `platform/argocd-apps/` manage all platform components.
- `platform-manifests` is the App-of-Apps root: it manages all other 12 Application manifests via kustomize (`platform/kustomization.yaml`). Only `platform-manifests.yaml` itself requires `kubectl apply` on bootstrap — a standard chicken-and-egg constraint inherent to any App-of-Apps pattern, not a gap.
- `helmfile apply` is retained only for bootstrapping ArgoCD itself and for CI linting/validation.
- ArgoCD itself requires bootstrapping — it cannot deploy itself on first install (see ADR-016 for the duplication this creates).
- The ArgoCD UI is exposed at `argocd.cereghino.me` with Dex SSO (ADR-020).
- Automated sync with self-heal and pruning is enabled on all Applications.
