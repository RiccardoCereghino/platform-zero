# ADR-001: Cloud Provider Selection

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

The project needed a cloud provider to host Kubernetes nodes. The primary constraint was cost — this is a personal portfolio project with no revenue, so monthly spend needed to stay minimal while still demonstrating production-grade practices.

### Alternatives Considered

- **AWS / GCP / Azure** — Industry standards with managed Kubernetes offerings (EKS, GKE, AKS), but significantly more expensive for raw compute. Managed K8s services also abstract away the operational layer this project exists to demonstrate.
- **Aruba / Scaleway** — European alternatives with competitive pricing, but weaker Kubernetes ecosystem tooling and community integrations.
- **Local bare metal** — Zero recurring cost, but introduces hardware maintenance, networking complexity, and availability concerns that distract from the project's goals.

## Decision

Use **Hetzner Cloud** for all compute, networking, and object storage resources.

## Rationale

Hetzner provides raw, unmanaged virtual machines at roughly 1/3 to 1/5 the cost of equivalent instances on AWS or GCP. This forces the project to build the full Kubernetes lifecycle from scratch (provisioning, networking, storage, backups) rather than leaning on managed services — which is the entire point of a Platform Engineering portfolio. Hetzner's API is well-supported by the Terraform/OpenTofu ecosystem, has first-party CSI and CCM integrations for Kubernetes, and offers S3-compatible object storage for state and backups.

## Consequences

- All infrastructure tooling must be compatible with Hetzner's API and networking model.
- No managed Kubernetes — full responsibility for control plane lifecycle, upgrades, and HA.
- S3-compatible storage uses Hetzner's endpoint format, not AWS, requiring endpoint overrides in provider configs.
- Limited geographic redundancy compared to hyperscalers (European DCs only at time of decision).
