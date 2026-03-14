# ADR-008: Container Network Interface Selection

**Status:** Implemented
**Date:** 2026-02-28
**Author:** Riccardo Cereghino

## Context

Kubernetes requires a CNI plugin to provide pod-to-pod networking, network policy enforcement, and service load balancing.

## Alternatives Considered

- **Calico** — Mature, well-documented, supports network policies natively. Uses iptables or eBPF (newer versions). Strong community adoption.
- **Flannel** — Simple overlay network, minimal configuration. No native network policy support — requires pairing with another tool.

## Decision

Use **Cilium** as the CNI, leveraging eBPF for all networking operations.

## Rationale

Cilium operates directly in the Linux kernel via eBPF programs, bypassing iptables entirely. This provides measurably better performance at scale and enables capabilities that traditional CNIs cannot offer: transparent encryption (WireGuard), deep network observability (Hubble), native Gateway API implementation, and full kube-proxy replacement. Cilium is a CNCF graduated project with strong momentum in the Kubernetes ecosystem.

The combination of CNI + kube-proxy replacement + Gateway API + network visibility in a single component reduces the number of moving parts in the cluster significantly.

## Consequences

- eBPF requires a sufficiently recent kernel (Talos Linux satisfies this).
- Cilium's operational model differs from Calico — troubleshooting uses `cilium` CLI and Hubble rather than `iptables` inspection.
- Network policies use CiliumNetworkPolicy CRDs (superset of standard Kubernetes NetworkPolicy).
- The cluster is coupled to Cilium for multiple functions (CNI, proxy, gateway, observability), increasing the blast radius if Cilium has issues.
