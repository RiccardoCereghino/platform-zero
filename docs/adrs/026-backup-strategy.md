# ADR-026: Backup Strategy (etcd + Velero)

**Status:** Implemented
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

Two categories of data need protection: the Kubernetes cluster state (stored in etcd) and application data (stored in Persistent Volumes). Losing etcd means losing all cluster configuration, workload definitions, and secrets. Losing PV data means losing application state (databases, uploaded files).

## Decisions

### etcd Backups

**Tool:** Native `talos-backup`, configured via OpenTofu.

**Mechanism:** Automated CronJob pushes encrypted etcd snapshots to Hetzner S3 (`cereghino-infra-backups` bucket in nbg1 region). Snapshots are encrypted with an age X25519 public key.

**Alternatives considered:** Custom CronJobs, or no backups (relying solely on GitOps for cluster state). GitOps covers declarative resources but not runtime state like Secrets, CRDs, or dynamically created resources.

### Application Data Backups

**Tool:** Velero with `velero-plugin-for-aws`.

**Backup agent:** Kopia (not Restic). The initial planning documents referenced Restic, but when the actual deployment was configured, Kopia was chosen as the node agent. Kopia provides better deduplication, encryption, and performance compared to Restic's older architecture.

**Mechanism:** Velero backs up Kubernetes manifests and uses the Kopia node agent for file-level Persistent Volume backups, streaming to the same Hetzner S3 bucket (prefix: `velero/`).

**Why file-level instead of CSI snapshots:** Hetzner CSI snapshots are point-in-time volume copies that stay within Hetzner's infrastructure. File-level backups via Kopia stream data to S3 in a different region (ADR-007), providing geographic redundancy that CSI snapshots alone cannot.

## Consequences

- Both backup paths write to the same S3 bucket (`cereghino-infra-backups`) but use different prefixes.
- A full disaster recovery requires both: etcd snapshot to rebuild the cluster, Velero to restore application data.
- The `velero` namespace has `pod-security.kubernetes.io/enforce: privileged` labels because the Kopia node agent DaemonSet requires host filesystem access.
- DR drills (destroy a node, restore from backup) are planned but not yet executed — documented in TODO.md.
- Losing the age private key makes etcd snapshots unrecoverable. The key is backed up in Vaultwarden.
