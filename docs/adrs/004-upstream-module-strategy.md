# ADR-004: Upstream Module Clone and Sync Strategy

**Status:** Implemented
**Date:** 2026-02-28
**Author:** Riccardo Cereghino

## Context

The cluster infrastructure is built on the `hcloud-k8s/terraform-hcloud-kubernetes` community template — a comprehensive OpenTofu module for provisioning Talos Linux clusters on Hetzner Cloud. The question was how to consume this module: as an opaque dependency or as owned source code.

## Alternatives Considered

- **Remote Terraform registry module** — Clean dependency management, automatic version updates, but acts as a black box. Impossible to read, modify, or learn from the internals. Module inputs constrain what you can customize.
- **Direct clone with manual git rebasing** — Full ownership, but merging upstream changes into a diverged codebase is error-prone and tedious.
- **Feature flags to disable unwanted modules** — Keep the upstream module intact, toggle off unused parts via variables. Cleaner than deleting code, but still treats the module as a black box.

## Decision

Clone the template repository directly into the `infrastructure/` directory, taking full ownership of all `.tf` files. Implement a custom `upstream-sync.sh` script to track upstream changes without git-based rebasing.

## Rationale

The primary goal of this project is learning and demonstrating mastery of the infrastructure stack. Using the module as a remote dependency would hide the raw Terraform logic that provisions nodes, configures Talos, and bootstraps Kubernetes. By cloning the code, every line is visible, modifiable, and reviewable.

The `upstream-sync.sh` script solves the maintenance problem: it diffs the local repository against upstream tags or the `main` branch, generates patch files, and lets the operator see exactly what changed upstream. This allows cherry-picking improvements and bug fixes without blindly rebasing.

## Consequences

- Full code ownership — the project can modify any `.tf` file freely.
- `upstream-sync.sh` must be run periodically to check for upstream improvements.
- Divergence from upstream grows over time; large upstream refactors may be difficult to reconcile.
- The project carries maintenance burden for code that the upstream community might otherwise maintain.
- Upstream's default components (ingress-nginx, Longhorn) were disabled or removed since the project uses its own stack (Cilium Gateway API, Hetzner CSI).
