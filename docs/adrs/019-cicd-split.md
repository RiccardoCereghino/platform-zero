# ADR-019: CI/CD Pipeline Split Between GitHub Actions and ArgoCD

**Date:** 2026-03-01
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

The cluster needs both continuous integration (validating changes before they land) and continuous delivery (applying changes to the cluster). These are fundamentally different concerns with different security requirements — CI needs to read and validate code, while CD needs write access to the cluster.

### Alternatives Considered

- **Jenkins** — Self-hosted, highly customizable, but heavy operational overhead and a dated UX.
- **GitLab CI** — Tightly integrated CI/CD, but the project is on GitHub.
- **Manual local execution** — Running `tofu plan` and `helmfile apply` from a developer laptop. No automation, no audit trail, requires operator presence.
- **GitHub Actions for both CI and CD** — Possible, but storing kubeconfig credentials in GitHub means high-privilege cluster access lives outside the cluster's security boundary.

## Decision

Split the pipeline: **GitHub Actions handles CI** (testing, linting, validation, OpenTofu plan/apply), while **ArgoCD handles CD** (Kubernetes manifest synchronization via pull-based GitOps).

## Rationale

This split keeps cluster credentials out of GitHub. ArgoCD runs in-cluster and pulls changes from Git — it never exposes kubeconfig externally. GitHub Actions handles the "pre-merge" validation (tofu fmt, tofu validate, tofu plan, yamllint, helmfile lint, helmfile template + kubeconform) and the infrastructure CD (`tofu apply` on push to master, which does require Hetzner API tokens but not kubeconfig). Platform delivery is entirely ArgoCD's responsibility.

The free GitHub-hosted runners (`runs-on: ubuntu-latest`) are sufficient for the CI workload. Self-hosted runners via Actions Runner Controller were evaluated (see ADR-029) but deemed unnecessary.

## Consequences

- Two CI jobs run on every push/PR: Infrastructure CI (tofu fmt/validate/plan) and Platform CI (yamllint, helmfile lint, kubeconform).
- Infrastructure CD (`cd-infra.yaml`) runs `tofu apply -auto-approve` on push to master for changes in `infrastructure/**`.
- Platform CD is fully handled by ArgoCD — no GitHub Actions workflow needed.
- PR comments show the tofu plan output for review before merge.
- Hetzner and S3 credentials are stored in GitHub Actions secrets; kubeconfig is not.
