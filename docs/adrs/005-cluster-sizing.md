# ADR-005: Initial Cluster Sizing

**Status:** Implemented
**Date:** 2026-02-28
**Author:** Riccardo Cereghino

## Context

The cluster needs enough compute to run the platform stack (Cilium, ArgoCD, Prometheus, etc.) while keeping costs minimal. This is a portfolio project, not a production workload, so cost efficiency matters more than peak capacity.

## Alternatives Considered

- **HA setup: 3 Control Plane + 3 Workers** — True high availability with etcd quorum, but roughly 3x the cost for control plane nodes that would sit mostly idle.

## Decision

Start with **1 Control Plane node (CX22) and 2 Worker nodes (CX22/CPX22)**.

## Rationale

A single control plane is sufficient for learning, development, and portfolio demonstration. The cost savings are significant — spending on idle HA control plane nodes yields diminishing returns compared to investing time in building out the GitOps, observability, and security layers. Scaling to 3 CP nodes is explicitly planned as a future upgrade (see TODO.md) once the platform layer is mature.

## Consequences

- No etcd quorum — a control plane failure means full cluster downtime.
- No API server redundancy — `kubectl` and ArgoCD lose connectivity if the CP node is unavailable.
- etcd backups via `talos-backup` are critical as the sole recovery mechanism.
- Upgrading to HA later requires adding nodes and reconfiguring Talos, which is a non-trivial operation.
