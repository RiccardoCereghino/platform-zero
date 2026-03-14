# ADR-012: Load Balancer PROXY Protocol and IPv6 Trade-off

**Status:** Implemented
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

The Hetzner Layer 4 Load Balancer sits in front of the Cilium Gateway (Envoy). By default, Envoy sees the load balancer's IP as the client source address, losing the real user IP. This breaks rate limiting, WAF rules, access logs, and any logic that depends on client identity.

## Alternatives Considered

- **Plain TCP passthrough** — Preserves simplicity but caused connection resets and loses client IP information entirely.

## Decision

Initially enabled **PROXY Protocol** via the `load-balancer.hetzner.cloud/uses-proxyprotocol: "true"` annotation on the Gateway manifest. Subsequently **disabled** it (`cilium_gateway_api_proxy_protocol_enabled = false`) due to a Cilium bug.

## Rationale

PROXY Protocol is the standard mechanism for L4 load balancers to pass client IP metadata to the backend. However, a known Cilium Gateway API bug causes IPv6 external connections to fail when PROXY Protocol is enabled. Since IPv6 connectivity was considered more important than client IP preservation at this stage, PROXY Protocol was disabled.

## Consequences

- Client source IP is currently not preserved through the load balancer to Envoy.
- WAF rules and rate limiting that depend on client IP operate on the load balancer's IP instead.
- This decision should be revisited when the Cilium bug is resolved upstream.
- IPv6 connectivity works correctly.
