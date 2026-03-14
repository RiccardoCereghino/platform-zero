# ADR-009: Kube-Proxy Replacement with Cilium eBPF

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

Kubernetes traditionally uses kube-proxy to handle service routing via iptables rules. With Cilium selected as the CNI (ADR-008), the option exists to replace kube-proxy entirely with Cilium's eBPF-based implementation.

### Alternatives Considered

- **Standard iptables-based kube-proxy** — Works everywhere, well understood, but performance degrades as the number of services grows (O(n) iptables rules). Adds a separate component to manage alongside Cilium.

## Decision

Enable complete kube-proxy replacement in **strict mode**, managed natively by Cilium's eBPF datapath. This is also the default for Talos Linux when Cilium is the CNI.

## Rationale

Running both kube-proxy and Cilium creates redundant service routing paths. Strict mode eliminates kube-proxy entirely, letting Cilium handle all service load balancing via eBPF maps with O(1) lookup performance. Fewer components means fewer things to monitor, debug, and upgrade.

## Consequences

- kube-proxy is not deployed — `kubectl get pods -n kube-system` will not show kube-proxy pods.
- All service routing depends on Cilium. If Cilium fails, services become unreachable.
- XDP acceleration (`native` mode) is enabled for additional performance on supported hardware.
