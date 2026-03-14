# ADR 032: Implementation of Netbird for Secure Kubernetes and Talos API Access

**Date:** 2026-03-14
**Status:** Accepted
**Author(s):** Riccardo Cereghino

## Context
On 2026-03-14, the operator suffered a complete loss of access to both the Kubernetes API and the Talos Linux control plane. The Hetzner Cloud firewall, provisioned via OpenTofu, utilized a strict IP allowlist that failed silently when the residential ISP assigned a new dynamic IPv4 address.

Relying on Infrastructure as Code (IaC) to manage dynamic state variables creates inherent drift and brittleness. Furthermore, directly exposing critical control plane endpoints (ports 6443 and 50000) to the public internet violates zero-trust principles and unnecessarily expands the attack surface.

A permanent access solution is required. Talos Linux utilizes a gRPC API on port 50000 that mandates strict, end-to-end mutual TLS (mTLS) verified against an internal, privately held Certificate Authority. Therefore, any solution that terminates TLS traffic (such as Layer 7 proxies) will break the cryptographic chain of trust. The solution must operate transparently at Layer 3 or Layer 4. Additionally, since this is a single-operator homelab, the chosen solution must be fully open-source, avoid SaaS vendor lock-in, bypass scaling paywalls, maintain a low resource footprint, and ideally align with the Cloud Native Computing Foundation (CNCF).

## Decision
We will implement Netbird, a fully open-source, self-hosted WireGuard-based mesh VPN, as the primary access layer for the cluster.

The Netbird control plane will be self-hosted to maintain total infrastructure sovereignty. We will leverage the official Netbird Kubernetes Operator to automatically expose the Kubernetes API and internal cluster services to the encrypted tailnet. Following successful deployment, all Hetzner firewall rules permitting inbound public traffic to ports 6443 and 50000 will be permanently deleted.

## Rationale
Netbird provides the optimal equilibrium between operational ease, robust security, and open-source sovereignty. Because it operates as a Layer 3 overlay network routing raw TCP packets over WireGuard, it perfectly preserves the complex mTLS handshakes required by the Talos API. It is heavily invested in the open-source community, maintaining Silver Member status within the CNCF. Its native Kubernetes operator dramatically simplifies declaring zero-trust access to cluster services.

* **Alternative 1:** Cloudflare Tunnel - Rejected. While free and lightweight, Cloudflare Access functions by terminating the connection at the edge to inspect traffic and authenticate users. This Layer 7 interception breaks the strict mTLS requirements of the Talos API, resulting in certificate validation failures. Utilizing "Arbitrary TCP" mode forces reliance on a proprietary SaaS network for critical control plane traffic.
* **Alternative 2:** Tailscale - Rejected. Tailscale provides excellent WireGuard mesh networking and NAT traversal, but its coordination server is a proprietary, closed-source SaaS product. This violates the requirement to avoid external SaaS dependencies and potential future scaling paywalls.
* **Alternative 3:** Headscale - Rejected. While it solves the Tailscale SaaS dependency by providing an open-source control plane, it is explicitly designed for personal use with a SQLite backend that struggles under heavy load. It lacks an official Kubernetes Operator, requiring manual sidecar configurations, and constantly runs the risk of falling out of compatibility with official Tailscale clients.
* **Alternative 4:** Teleport (Community Edition) - Rejected. Teleport is a powerful open-source identity proxy, but its resource overhead is designed for enterprise scale. Recommended production specifications demand instances with up to 16GB of RAM for the Auth Service, which is unacceptably heavy for a constrained homelab environment.
* **Alternative 5:** Hetzner API Script (e.g., hcloud-firewall-controller) - Rejected. While tools like the Rust-based hcloud-firewall-controller can dynamically sync the Hetzner firewall with a changing home IP, they perpetuate the architectural anti-pattern of exposing cluster APIs to the public internet. They also cause constant state drift, conflicting with the OpenTofu .tfstate file.

## Consequences
* **Positive:** Completely eliminates cluster access lockouts caused by dynamic residential IP rotations.
* **Positive:** Removes the Kubernetes and Talos APIs from the public internet, migrating the architecture to a "dark network" model and drastically reducing the attack surface.
* **Positive:** Maintains compliance with the operator's open-source, non-SaaS, and CNCF-aligned philosophy.
* **Negative:** Introduces the operational overhead of self-hosting and maintaining the Netbird control plane (Management, Signal, Relay, and STUN/TURN servers).
* **Neutral:** Requires updating OpenTofu configurations to remove legacy public firewall rules and modifying operational runbooks to reflect the new VPN-first access requirement.
