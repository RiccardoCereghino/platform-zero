# ADR-011: Layer 7 Ingress with Gateway API

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

HTTP/HTTPS traffic from the internet needs to be routed to the correct services inside the cluster, with TLS termination, host-based routing, and path matching.

### Alternatives Considered

- **Traefik** — Feature-rich, auto-discovery, good dashboard. Widely used in homelabs and K3s clusters.
- **ingress-nginx** — The Kubernetes community default. Stable and well-documented but based on the older Ingress API. The upstream module shipped it by default.
- **Envoy via Contour** — Powerful L7 proxy with advanced traffic management, but adds another component to manage separately from the CNI.

## Decision

Use **Cilium Gateway API**, which implements the Kubernetes Gateway API specification using Envoy embedded directly in Cilium.

## Rationale

Gateway API is the successor to the Ingress API — it's a forward-looking standard with richer routing semantics (header matching, traffic splitting, cross-namespace references). Since Cilium already runs as the CNI, using its built-in Gateway API implementation means Envoy is managed by Cilium rather than deployed as a separate component. This eliminates an entire layer of infrastructure.

The upstream module's default ingress-nginx was explicitly disabled (`ingress_nginx_enabled = false`) and the ingress-nginx namespace was manually purged to avoid port conflicts with Cilium's Gateway.

## Consequences

- All routing is configured via HTTPRoute resources rather than Ingress resources.
- Cross-namespace routing requires explicit ReferenceGrant resources.
- Cilium manages the Envoy lifecycle — Envoy proxy pods are created automatically when a Gateway resource is deployed.
- Gateway API is still evolving; some advanced features may be in beta or experimental channels.
- Less community documentation compared to ingress-nginx for common recipes.
