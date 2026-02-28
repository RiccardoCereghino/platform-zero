# TODO — Unresolved Architectural Decisions

> This file tracks architectural gaps in the Kubernetes platform.  
> Each section is a decision to be made — not a bug to fix.

---

## 1. Stateful Data / Databases

**Question:** How should we run databases in the cluster?

**Option A — Hetzner Block Volumes (CSI)**
- Use the Hetzner CSI driver (already deployed) to provision network-attached volumes.
- Run a database operator like [CloudNativePG](https://cloudnative-pg.io) on top.
- Pros: Simple, managed backups via Hetzner snapshots, no extra infra.
- Cons: Network latency (~1ms), IOPS capped by Hetzner volume tier.

**Option B — Local NVMe + Distributed Storage**
- Use dedicated server types with local NVMe (e.g., CCX/CAX with local disks).
- Pool disks with [Longhorn](https://longhorn.io) (already available in module) or Ceph/Rook.
- Pros: Higher IOPS, lower latency for write-heavy workloads.
- Cons: More complex, requires replication config, node loss = data risk.

**Decision criteria:** Profile the actual workload first. CSI volumes are the 80/20 choice for most apps.

---

## 2. Disaster Recovery

**Question:** How do we protect cluster state and application data?

### etcd Snapshots
- The module supports [Talos Backup](https://github.com/siderolabs/talos-backup) out of the box.
- Configure `talos_backup_s3_hcloud_url` in `terraform.tfvars` to push etcd snapshots to [Hetzner Object Storage](https://docs.hetzner.com/storage/object-storage).
- **Action:** Create an Object Storage bucket and add the S3 credentials to tfvars.

### Application Backup
- Evaluate [Velero](https://velero.io) for backing up:
  - Kubernetes manifests (Deployments, Services, ConfigMaps)
  - Persistent Volume data (via CSI snapshots or Restic)
- Alternative: If using GitOps (see §5), manifests are already in Git — only PV data needs backup.

### Recovery Testing
- Document and test a full recovery runbook:
  1. Recreate cluster from `tofu apply`
  2. Restore etcd from snapshot
  3. Restore PV data from Velero / Object Storage

---

## 3. Layer 7 Traffic & Security

**Question:** How do we handle HTTP routing, TLS termination, and WAF?

### Ingress Controller
Hetzner Load Balancers are L4 only. An in-cluster L7 proxy is required.

| Option | Notes |
|--------|-------|
| **Cilium Gateway API** | Already bundled in module (`cilium_gateway_api_enabled`). Modern Gateway API spec. Envoy-backed. Recommended starting point. |
| **Traefik** | Mature, good dashboard, middleware ecosystem. Consider if you need advanced routing. |
| **Envoy / Contour** | Raw Envoy via Contour. More control, more config. |
| **ingress-nginx** | Being [retired March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/). Avoid for new projects. |

**Recommendation:** Start with Cilium Gateway API since the module already supports it. Enable with:
```hcl
cilium_gateway_api_enabled = true
cert_manager_enabled       = true
```

### WAF (Web Application Firewall)
- Evaluate [Coraza](https://coraza.io) as a WAF sidecar or middleware.
- Coraza implements OWASP Core Rule Set (CRS) and can be embedded in Envoy/Traefik.
- Alternative: Cloudflare/Fastly in front for edge WAF + DDoS protection.

---

## 4. Observability & Monitoring

**Question:** How do we observe cluster and application health?

- **Metrics:** Deploy Prometheus + Grafana (the module already installs Prometheus Operator CRDs via `prometheus_operator_crds_enabled`).
  - Options: [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) Helm chart, or Victoria Metrics for lower resource usage.
- **Logging:** Centralized log aggregation.
  - Options: Loki + Promtail (lightweight), or Elastic/OpenSearch (heavyweight).
  - Consider Talos `talos_logging_destinations` variable for sending machine-level logs.
- **Tracing:** OpenTelemetry Collector → Tempo or Jaeger for distributed tracing.
- **Alerting:** Alertmanager → PagerDuty / Slack / Email.

---

## 5. GitOps / Continuous Delivery

**Question:** How do changes get deployed to the cluster?

| Option | Notes |
|--------|-------|
| **ArgoCD** | Pull-based GitOps. Watches a Git repo, auto-syncs to cluster. Rich UI. |
| **Flux** | Pull-based GitOps. Lighter weight, more composable. |
| **CI-driven `kubectl apply`** | Push-based. Simpler but less auditable. |

**Consideration:** Since this is a monorepo, ArgoCD/Flux can watch `apps/` and `platform/` directories for manifests. Infrastructure changes in `infrastracture/` stay with `tofu apply` (either manual or CI-gated).

---

## 6. Secrets Management

**Question:** How do we get secrets into the cluster securely?

| Option | Notes |
|--------|-------|
| **External Secrets Operator** | Syncs secrets from external stores (1Password, Vault, AWS SM) into K8s Secrets. Since we already use 1Password, this is a natural fit with the [1Password Connect provider](https://github.com/external-secrets/external-secrets). |
| **Sealed Secrets** | Encrypt secrets in Git. Decrypted in-cluster by a controller. |
| **SOPS + age** | Encrypt secret files with age keys. Decrypt at deploy time. |

---

## 7. DNS Automation

**Question:** How do DNS records get created when services are exposed?

- [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) can auto-create DNS records from Gateway/Ingress annotations.
- Supports Hetzner DNS, Cloudflare, Route53, etc.
- Pairs well with Cert Manager for automated TLS.

---

## 8. Scaling Strategy

**Question:** When do we enable the Cluster Autoscaler?

- Current setup is static: 1 CP + 2 Workers.
- The module supports autoscaler nodepools (`cluster_autoscaler_nodepools` variable).
- **Decision point:** Enable when workloads have variable demand. For now, manual `count` changes in `terraform.tfvars` are sufficient.
- **HA upgrade path:** Scale to 3 CP nodes before running any production workloads (etcd quorum requires odd number ≥ 3).

---

## 9. Multi-Environment Strategy

**Question:** How do we separate dev / staging / production?

| Option | Notes |
|--------|-------|
| **Namespaces** | Single cluster, workloads separated by namespace + RBAC + NetworkPolicy. Cheapest. |
| **Separate clusters** | Full isolation. Expensive but safest. Use OpenTofu workspaces or separate tfvars. |
| **Kustomize overlays** | Base manifests in `platform/`, per-env overlays. Works with both options above. |

**Recommendation:** Start with namespaces. Migrate to separate clusters only if compliance or blast-radius requires it.
