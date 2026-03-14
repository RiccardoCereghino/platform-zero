# ADR-014: Default-Allow Network Policy During Bootstrap

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

Cilium supports enforcing network policies that control which pods can communicate. The default mode determines whether traffic is allowed or denied when no explicit policy exists for a pod.

### Alternatives Considered

- **Default-deny (strict)** — Every pod must have an explicit policy allowing its traffic. Most secure, but blocks all communication until policies are written for every service.

## Decision

Use **default-allow mode** during the initial setup phase.

## Rationale

During the learning and bootstrapping phase, strict network policies would block test traffic and make it extremely difficult to debug connectivity issues between new components. Default-allow lets everything communicate while the platform is being built. Migrating to default-deny CiliumNetworkPolicy is planned as a Tier 1 priority in TODO.md once all services are stable and their communication patterns are understood (Hubble provides the visibility needed to write accurate policies).

## Consequences

- All pods can currently communicate with all other pods — no network segmentation.
- Exposed services (WAF, Grafana) can reach internal components they shouldn't need to access.
- This is explicitly temporary and tracked as a priority item.
- Hubble flow logs should be used to map actual traffic patterns before writing deny policies.
