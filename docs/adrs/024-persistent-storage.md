# ADR-024: Persistent Storage Backend Selection

**Date:** 2026-03-01
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

Stateful workloads (Vaultwarden/PostgreSQL, Prometheus, Grafana) need persistent storage that survives pod restarts and rescheduling. The choice of storage backend affects reliability, performance, cost, and operational complexity.

### Alternatives Considered

- **Rook Ceph** — Distributed storage system providing block, file, and object storage. Extremely capable but resource-hungry: requires multiple OSDs, monitors, and managers. Too heavy for a 3-node cluster where the storage infrastructure would consume a significant portion of available resources.
- **Longhorn** — Lightweight distributed block storage by Rancher/SUSE. Provides replicated volumes across nodes, snapshots, and ReadWriteMany (RWX) support. The upstream module includes it as an option. Attractive for its resilience, but requires more setup and configuration than was justified given the project timeline and immediate objectives. Deferred as a future "sidegrade" if RWX storage is specifically needed.

## Decision

Use **Hetzner CSI (Cloud Volumes)** as the primary storage backend, with a custom StorageClass named `vault-storage`.

## Rationale

Hetzner Cloud Volumes are managed by Hetzner — no storage infrastructure to operate, no replica management, no distributed system to debug. They attach as network block devices and work reliably with minimal configuration. For a project focused on platform engineering rather than storage engineering, the simplicity is the right trade-off.

The custom `vault-storage` StorageClass adds:
- `reclaimPolicy: Retain` — prevents accidental data deletion when a PVC is removed.
- `allowVolumeExpansion: true` — volumes can grow without downtime.
- `LUKS encryption` (`encrypted: true`) — data is encrypted at rest on the volume.

## Consequences

- Volumes are tied to a single Hetzner location — no cross-region replication.
- ReadWriteMany (RWX) is not available. Workloads requiring shared storage will need Longhorn or an alternative.
- Hetzner Cloud Volumes have a minimum size (10GB) which may be oversized for small workloads.
- Longhorn remains disabled (`longhorn_enabled = false`) but available as a future option.
- Velero handles volume backup to S3 since Hetzner CSI doesn't provide built-in snapshot-to-S3 capability.
