# Architecture Decision Records

This directory contains the Architecture Decision Records (ADRs) for Platform Zero.

> ADRs 001–030 were written retroactively to document decisions made during the initial project build. Going forward, new ADRs are written before or during implementation.

## How ADRs work

- **One decision per file.** Each ADR captures a single architectural choice.
- **ADRs are immutable.** Never edit a past decision. If a decision changes, write a new ADR and mark the old one as `Superseded by ADR-XXX`.
- **Write ADRs before or during implementation.** Start with `Evaluating` while researching, move to `Proposed` once you have a direction, then `Accepted` once committed.
- **Status lifecycle:** `Evaluating` → `Proposed` → `Accepted` → `Implemented` | `Deprecated` | `Superseded by ADR-XXX`

| Status | Meaning |
|--------|---------|
| **Evaluating** | Actively researching. Alternatives are being compared, no commitment yet. |
| **Proposed** | A direction has been chosen but not yet approved or implemented. |
| **Accepted** | Decision is final. Implementation may or may not have started. |
| **Implemented** | Decision is final and running in the cluster. |
| **Deprecated** | Was implemented, but experience showed it should be replaced. |
| **Superseded** | Replaced by a newer ADR. Link to the successor. |

## Index

### Infrastructure Foundation

| ADR | Title | Status |
|-----|-------|--------|
| [001](001-cloud-provider.md) | Cloud provider selection | Implemented |
| [002](002-operating-system.md) | Operating system and Kubernetes distribution | Implemented |
| [003](003-iac-tooling.md) | Infrastructure as Code tooling | Implemented |
| [004](004-upstream-module-strategy.md) | Upstream module clone and sync strategy | Implemented |
| [005](005-cluster-sizing.md) | Initial cluster sizing | Implemented |
| [006](006-terraform-state.md) | Terraform state storage | Implemented |
| [007](007-s3-bucket-architecture.md) | S3 bucket architecture and multi-region DR | Implemented |

### Networking

| ADR | Title | Status |
|-----|-------|--------|
| [008](008-cni-selection.md) | Container Network Interface selection | Implemented |
| [009](009-kube-proxy-replacement.md) | Kube-proxy replacement with Cilium eBPF | Implemented |
| [010](010-network-encryption.md) | Pod-to-pod encryption with WireGuard | Implemented |
| [011](011-ingress-strategy.md) | Layer 7 ingress with Gateway API | Implemented |
| [012](012-proxy-protocol.md) | Load balancer PROXY protocol and IPv6 trade-off | Implemented |
| [013](013-dns-and-tls.md) | Automated DNS and TLS certificate management | Implemented |
| [014](014-network-policy-mode.md) | Default-allow network policy during bootstrap | Implemented |

### Platform & GitOps

| ADR | Title | Status |
|-----|-------|--------|
| [015](015-helmfile-to-argocd.md) | Migration from Helmfile to ArgoCD | Implemented |
| [016](016-helmfile-argocd-duplication.md) | Helmfile and ArgoCD value duplication | Accepted |
| [017](017-sops-age-secrets.md) | Secret management with SOPS + age | Implemented |
| [018](018-local-secrets-workflow.md) | Local secrets workflow migration | Implemented |
| [019](019-cicd-split.md) | CI/CD pipeline split between GitHub Actions and ArgoCD | Implemented |

### Identity & Access

| ADR | Title | Status |
|-----|-------|--------|
| [020](020-unified-oidc.md) | Unified OIDC architecture with Dex | Implemented |
| [021](021-dex-auth-filtering.md) | Dex authorization filtering strategy | Implemented |

### Security

| ADR | Title | Status |
|-----|-------|--------|
| [022](022-waf-coraza.md) | Web Application Firewall with Coraza | Deprecated |
| [023](023-policy-enforcement.md) | Pod security and policy enforcement | Proposed |

### Storage & Data

| ADR | Title | Status |
|-----|-------|--------|
| [024](024-persistent-storage.md) | Persistent storage backend selection | Implemented |
| [025](025-vaultwarden.md) | Self-hosted password manager with Vaultwarden | Implemented |
| [026](026-backup-strategy.md) | Backup strategy (etcd + Velero) | Implemented |

### Strategic (Not Yet Operational)

| ADR | Title | Status |
|-----|-------|--------|
| [027](027-crossplane.md) | Crossplane as infrastructure control plane | Accepted |
| [028](028-backstage.md) | Backstage as internal developer portal | Accepted |
| [029](029-self-hosted-runners.md) | Self-hosted GitHub Actions runners | Superseded by ADR-019 |
| [030](030-grafana.md) | Grafana as observability frontend | Accepted |

### Operational Maturity

| ADR | Title | Status |
|-----|-------|--------|
| [031](031-disable-longhorn-backstage-crossplane.md) | Disable non-essential platform components | Implemented |
| [032](032-netbird-access.md) | Secure cluster access via Netbird WireGuard VPN | Accepted |
| [033](033-default-deny-network-policy.md) | Migration to default-deny network policy | Proposed |
| [035](035-alerting-strategy.md) | Alerting strategy with Alertmanager and ntfy | Proposed |
| [036](036-observability-frontend.md) | Observability frontend — evaluating Perses as Grafana replacement | Evaluating |
| [037](037-edc-evaluation-deployment.md) | Evaluation deployment of Eclipse Dataspace Connector | Evaluating |
