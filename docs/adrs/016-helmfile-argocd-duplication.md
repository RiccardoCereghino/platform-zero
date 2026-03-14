# ADR-016: Helmfile and ArgoCD Value Duplication

**Date:** 2026-03-03
**Status:** Accepted
**Author(s):** Riccardo Cereghino

## Context

After migrating to ArgoCD (ADR-015), Helm release values exist in two places: `platform/helmfile.yaml` (used by CI for linting and validation) and the corresponding ArgoCD Application manifests in `platform/argocd-apps/` (used by ArgoCD for actual deployment). When a Helm value changes, both files must be updated.

### Alternatives Considered

- **Drop helmfile entirely** — ArgoCD becomes the sole source of truth. CI validation would need to parse ArgoCD Application manifests and extract Helm values for linting, which is more complex.
- **Generate ArgoCD Applications from helmfile** — Use a script or tool to auto-generate Application manifests from helmfile releases. Eliminates duplication but adds build-time complexity and a generated-file maintenance burden.

## Decision

Accept the duplication as a known trade-off. Helm values live in both `helmfile.yaml` and ArgoCD Application manifests. Changes must be made in both places.

## Rationale

Helmfile provides a clean, battle-tested CI validation pipeline: `helmfile lint` and `helmfile template | kubeconform` catch schema errors, missing values, and invalid manifests before anything reaches the cluster. Replicating this validation by parsing ArgoCD Application manifests would be significantly more complex. The duplication is a maintenance cost, but the CI safety net it provides is worth it at this stage.

## Consequences

- Every Helm value change requires updating two files — forgetting one causes drift between CI validation and actual deployment.
- This is a known source of bugs and should be addressed as the project matures.
- A possible future improvement is generating one from the other, or migrating CI validation to use ArgoCD's own rendering.
