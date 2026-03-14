# ADR-010: Pod-to-Pod Encryption with WireGuard

**Status:** Implemented
**Date:** 2026-02-28
**Author:** Riccardo Cereghino

## Context

Pod-to-pod traffic within the cluster traverses the Hetzner private network. While this network is isolated, encrypting traffic at the pod level provides defense in depth.

## Alternatives Considered

- **No encryption** — Relies entirely on network-level isolation. Acceptable for dev environments, but doesn't demonstrate production security practices.
- **IPsec** — Mature protocol, supported by Cilium, but higher CPU overhead and more complex key management. Also incompatible with some Cilium features (e.g., netkit datapath mode).

## Decision

Enable **Cilium Transparent Encryption using WireGuard** (`cilium_encryption_type = "wireguard"`).

## Rationale

WireGuard is faster and simpler than IPsec, with a smaller codebase and better performance characteristics. Cilium handles key rotation automatically — there is no manual key management. The encryption is transparent to applications; pods communicate normally without any awareness of the encryption layer.

## Consequences

- Slight CPU overhead for encryption/decryption, though WireGuard is designed to be minimal.
- WireGuard kernel module must be available (Talos Linux includes it).
- Hubble network flow visibility still works — Cilium sees traffic before encryption.
- Cannot be combined with netkit datapath mode (project uses `veth` mode).
