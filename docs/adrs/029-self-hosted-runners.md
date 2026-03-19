# ADR-029: Self-Hosted GitHub Actions Runners

**Date:** 2026-03-01
**Status:** Superseded by ADR-038
**Author(s):** Riccardo Cereghino

## Context

GitHub Actions provides free CI minutes for public repositories using GitHub-hosted runners (`ubuntu-latest`). An alternative is deploying self-hosted runners inside the Kubernetes cluster using Actions Runner Controller (ARC), which spins up ephemeral worker pods on demand.

### Alternatives Considered

- **GitHub-hosted runners (free tier)** — Zero operational overhead, sufficient for the project's CI workload.
- **Actions Runner Controller (ARC)** — Self-hosted runners as ephemeral pods in the cluster. Provides more control over the runner environment and avoids GitHub's free tier limitations.

## Decision

Evaluated ARC but decided to use **GitHub-hosted free runners** instead.

## Rationale

The CI workload (linting, validation, tofu plan) is lightweight and fits comfortably within the free tier. Deploying ARC would add operational complexity (runner controller pods, RBAC, scaling configuration) for no practical benefit. Since ArgoCD handles all Kubernetes deployment (the CD side), the runners don't need cluster access — they only need Hetzner and S3 credentials for infrastructure operations.

## Consequences

- CI runs on ephemeral GitHub-hosted VMs with no access to the Kubernetes cluster.
- No self-hosted infrastructure to maintain for CI.
- If the project grows beyond the free tier, ARC remains a viable option.
