# ADR-002: Operating System and Kubernetes Distribution

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

A Kubernetes cluster requires both a host operating system and a method of bootstrapping the Kubernetes components. The choice here has deep implications for security posture, operational overhead, and how much of the stack the operator controls.

### Alternatives Considered

- **Ubuntu/Debian + kubeadm** — The traditional approach. Full SSH access, familiar package management, but requires ongoing OS patching, configuration drift is possible, and the attack surface is large.
- **Ubuntu/Debian + K3s** — Lightweight Kubernetes distribution, easy to bootstrap, but still runs on a general-purpose OS with SSH and mutable filesystem. Also available via the hetzner-k3s CLI tool.
- **Managed Kubernetes (AKS, EKS, GKE)** — Offloads control plane management entirely, but hides the operational complexity this project aims to demonstrate.

## Decision

Use **Talos Linux** as the operating system, which ships Kubernetes as its sole workload.

## Rationale

Talos is purpose-built for Kubernetes. It is immutable (no shell, no SSH, no package manager), API-driven (all configuration is declarative YAML applied via `talosctl`), and minimal (only the binaries needed to run containerd and a small set of system services). This eliminates entire categories of operational risk — there is no way to SSH in and make ad-hoc changes, no configuration drift, and the attack surface is dramatically smaller than a general-purpose Linux distribution.

Every node configuration change goes through the Talos API, which means the entire cluster OS state is versionable and reproducible. This aligns with the project's commitment to declarative, GitOps-driven infrastructure.

## Consequences

- No SSH access to nodes. All troubleshooting happens via `talosctl` or the Kubernetes API.
- The learning curve is steeper than traditional Linux — standard debugging tools (`htop`, `journalctl`, `apt`) don't exist.
- Talos-specific tooling is required: `talosctl` for node management, Talos Image Factory for custom images with extensions (e.g., QEMU guest agent).
- Kubernetes upgrades are handled through Talos machine config patches, not `kubeadm upgrade`.
- Some workloads that expect a traditional Linux environment (host mounts, specific kernel modules) may need Talos extensions or workarounds.
