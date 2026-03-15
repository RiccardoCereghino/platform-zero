# ADR-033: Migration to Default-Deny Network Policy

**Date:** 2026-03-14
**Status:** Proposed
**Author(s):** Riccardo Cereghino

## Context

ADR-014 established a default-allow network policy during the bootstrap phase. That decision was correct at the time — writing deny policies before understanding service communication patterns would have produced either overly permissive rules or constant breakage.

The platform is now stable. ArgoCD manages 9 active applications, Hubble provides L7 flow visibility, and all service communication patterns are well-understood. The original rationale for default-allow no longer applies.

More critically, the platform's security posture is inconsistent: pod-to-pod traffic is encrypted via WireGuard (ADR-010), external access routes through a WireGuard mesh VPN (ADR-032), OIDC authentication gates every dashboard (ADR-020), and secrets are encrypted at rest (ADR-017) — yet any compromised pod can freely communicate with every other pod in the cluster. Network segmentation is the missing layer.

### Traffic Patterns Observed via Hubble

The following communication map reflects actual observed flows:

- **ArgoCD** → Git repo (egress), Kubernetes API (cluster-internal)
- **cert-manager** → ACME endpoints (egress), Kubernetes API
- **Cilium** → Kubernetes API, inter-node (already handled by Cilium itself)
- **CNPG (PostgreSQL)** → intra-namespace replication, S3 (backup egress)
- **Dex** → GitHub OIDC (egress), OAuth2 Proxy (cross-namespace)
- **external-dns** → Cloudflare API (egress)
- **Grafana** → Prometheus (cross-namespace query)
- **kube-prometheus-stack** → all namespaces (metrics scraping)
- **OAuth2 Proxy** → Dex (cross-namespace), upstream services
- **Vaultwarden** → CNPG PostgreSQL (cross-namespace)
- **Velero** → S3 (backup egress), Kubernetes API

### Alternatives Considered

- **Per-service allow policies without changing default** — Adds policies but leaves the gap open for any unlisted service. Does not enforce least-privilege.
- **Namespace-level isolation only** — Blocks cross-namespace traffic but allows unrestricted intra-namespace communication. Insufficient for workloads sharing a namespace.

## Decision

Implement **default-deny CiliumNetworkPolicy** at the cluster level, with explicit allow policies for each service based on observed Hubble flows.

### Implementation Strategy

1. **Audit phase** — Deploy CiliumNetworkPolicy resources in **audit mode** (logging violations without blocking). Run for a minimum of 7 days to catch periodic traffic (CronJobs, certificate renewals, backup schedules).
2. **Policy authoring** — Write least-privilege policies per namespace, allowing only the flows documented above. Store policies as platform manifests managed by ArgoCD.
3. **Staged enforcement** — Enable enforcement one namespace at a time, starting with the least critical (e.g., `vaultwarden`), progressing to platform-critical namespaces (`argocd`, `cert-manager`) last.
4. **Monitoring integration** — Configure Hubble-based alerts for denied flows in Grafana to catch legitimate traffic blocked by overly strict policies.

### Policy Structure

Each namespace will have:
- A **default-deny ingress and egress** base policy
- Explicit **ingress allow** rules scoped to source namespace + pod selector
- Explicit **egress allow** rules scoped to destination CIDR, namespace, or FQDN
- A shared **egress allow for DNS** (kube-dns) applied cluster-wide

## Rationale

Default-deny is the only posture that enforces least-privilege at the network layer. Combined with WireGuard encryption (ADR-010) and the Netbird mesh VPN (ADR-032), it completes a defense-in-depth model: encrypted transport, authenticated access, and segmented communication. Every allowed flow is explicit, auditable, and version-controlled in Git.

The staged rollout with audit mode mitigates the risk of breaking services. Hubble's flow visibility — the exact tool ADR-014 recommended using before writing policies — provides the data needed to write accurate rules.

## Consequences

- **Positive:** Every allowed communication path is explicitly declared and version-controlled, making the cluster's network posture auditable.
- **Positive:** A compromised pod can no longer pivot freely across namespaces.
- **Positive:** Network policy manifests serve as living documentation of service dependencies.
- **Negative:** Every new service requires a corresponding network policy before it can communicate — increases deployment friction.
- **Negative:** Prometheus metrics scraping requires broad ingress allow rules across namespaces, partially weakening isolation.
- **Neutral:** CiliumNetworkPolicy resources add to the manifest count managed by ArgoCD, but they follow the same GitOps workflow as every other resource.

## References

- ADR-014: Default-allow network policy during bootstrap (superseded by this ADR)
- ADR-010: Pod-to-pod encryption with WireGuard
- ADR-032: Netbird for secure cluster access
- Cilium documentation: [Network Policy](https://docs.cilium.io/en/stable/security/policy/)
