# Platform Zero — Project Context

## What This Is

A production-grade Kubernetes homelab on Hetzner Cloud running Talos Linux, fully defined as code. Built as a DevOps/Platform Engineering portfolio project to demonstrate SRE practices and open career opportunities.

**Owner**: Riccardo Cereghino
**Domain**: cereghino.me
**Repository structure**: monorepo with `infrastructure/`, `platform/`, `apps/`, `scripts/`

---

## Infrastructure Layer

**Provisioning**: OpenTofu >= 1.9.0 (Terraform fork), based on `hcloud-k8s/terraform-hcloud-kubernetes` module (full local ownership of .tf files, not a module reference).

**Cloud**: Hetzner Cloud, location `nbg1` (Nuremberg).

**Cluster topology**:
- 1 Control Plane node (CPX22: 2 vCPU, 4GB RAM, 40GB SSD)
- 2 Worker nodes (CPX22 each)
- Single CP — no etcd quorum yet (planned: scale to 3 CP)

**OS**: Talos Linux v1.11.5 — immutable, API-managed, no SSH. Custom images built with Packer (AMD64 + ARM64).

**Terraform providers**: hcloud 1.60.1, talos 0.9.0, aws ~5.0, helm ~3.1.0, tls ~4.2.0, random ~3.8.0, http ~3.5.0.

**State backend**: S3 on Hetzner Object Storage, bucket `cereghino-tf-state`, key `k8s/terraform.tfstate`, region `hel1`.

**Key infrastructure files** (28 .tf files in `infrastructure/`):
- `terraform.tfvars` — cluster sizing, feature flags, versions
- `server.tf` — Hetzner server provisioning
- `talos.tf` / `talos_config.tf` — Talos cluster bootstrap and OS config
- `talos_backup.tf` — hourly etcd backups to S3 with age encryption
- `cilium.tf` — Cilium CNI with WireGuard, Gateway API, Hubble
- `firewall.tf` — Hetzner firewall rules
- `oidc.tf` — Kubernetes API OIDC via dex.cereghino.me
- `cert_manager.tf` — cert-manager with topology spread

---

## Networking

- **Cilium CNI**: eBPF-based, replaces kube-proxy entirely. WireGuard pod-to-pod encryption enabled. Egress gateway enabled.
- **Gateway API**: Layer 7 routing and TLS termination (not legacy Ingress).
- **ExternalDNS 1.15.0**: Syncs Gateway API resources to Cloudflare DNS.
- **Cert-Manager**: Automated Let's Encrypt TLS certificates.

---

## Platform Layer

Managed via **Helmfile** (`platform/helmfile.yaml`) with 8 Helm releases + raw Kubernetes manifests (11 YAML files).

### Helm Releases

| Release | Namespace | Purpose |
|---------|-----------|---------|
| external-dns 1.15.0 | external-dns | Cloudflare DNS sync |
| dex | auth | OIDC provider (GitHub OAuth2) |
| oauth2-proxy | kube-system | Identity-aware proxy for Hubble UI |
| vaultwarden 0.34.6 | vault | Password manager (PostgreSQL, LUKS-encrypted PV) |
| velero | velero | Kubernetes backup to Hetzner S3 |
| kube-prometheus-stack | monitoring | Prometheus + Grafana |
| waf (custom chart) | security | Coraza WAF with OWASP CRS |

### Exposed Services

| Service | Domain | Protection |
|---------|--------|------------|
| Dex | dex.cereghino.me | Direct (OIDC issuer) |
| Hubble UI | hubble.cereghino.me | OAuth2-Proxy (GitHub OIDC) |
| Vaultwarden | vault.cereghino.me | Coraza WAF |
| Grafana | grafana.cereghino.me | Coraza WAF |

### Security Stack

- **Dex**: OIDC issuer backed by GitHub OAuth2. Static clients: `oauth2-proxy`, `kubernetes-cli`.
- **OAuth2-Proxy**: Protects Hubble UI, email-based access control, PKCE S256.
- **Coraza WAF**: Custom Helm chart (`platform/waf-chart/`), Caddy + Coraza with OWASP CRS. Proxies to Vaultwarden and Grafana. Rule exclusions: SQLi (942100) for Vaultwarden API and Grafana query API.
- **OIDC kubeconfig**: kubectl auth flows through Dex → GitHub, no static tokens.

### Storage & Backup

- **Hetzner CSI**: `vault-storage` StorageClass with LUKS encryption, Retain policy.
- **Etcd backups**: Hourly CronJob → Hetzner S3 (`cereghino-infra-backups`), age X25519 encrypted.
- **Velero**: Kubernetes manifest + PV backup to S3 (prefix: `velero/`), node-agent enabled.

### Observability

- **kube-prometheus-stack**: Prometheus + Grafana (admin password: hardcoded `prom-operator` — known issue).
- **Cilium Hubble**: Network flow visualization, UI behind OAuth2-Proxy.
- **No alerting configured yet** — Alertmanager has no receivers.

---

## CI/CD

### ci.yaml (PR + push to master)
**Infrastructure job**: `tofu fmt -check` → `tofu init` → `tofu validate` → `tofu plan` (comments plan on PRs).
**Platform job**: `yamllint` → `helmfile lint` → `helmfile template` → `kubeconform -strict`.

### cd-infra.yaml (push to master, path: infrastructure/**)
Runs `tofu init` → `tofu apply -auto-approve`. Environment: Production.

**Gap**: No CD pipeline for platform layer — `helmfile apply` is manual.

---

## Local Development

**Secret management**: direnv (`.envrc`) with 1Password CLI integration. Secrets injected: HCLOUD_TOKEN, AWS keys, CSI encryption passphrase, Talos backup S3 credentials.

**Upstream sync**: `scripts/upstream-sync.sh` tracks changes from the upstream Terraform module, generates patch files.

---

## Known Issues & Technical Debt

### Critical
- **Plaintext secrets in git**: `platform/dex-secrets.yaml`, `vault-secrets.yaml`, `oauth2-proxy-secrets.yaml` contain secrets. Grafana admin password hardcoded in helmfile.yaml.

### Architectural Gaps
- Single control plane (no HA, no etcd quorum)
- No GitOps for platform (manual helmfile apply)
- No alerting (Prometheus without Alertmanager receivers)
- No default-deny network policies (Cilium capable but unenforced)
- WAF rule exclusions undocumented

---

## Roadmap (from TODO.md + evaluation)

### Tier 1 — Next Steps
1. External Secrets Operator or Sealed Secrets (remove plaintext secrets from git)
2. ArgoCD (GitOps for platform layer)
3. Platform CD workflow (GitHub Actions for helmfile apply)

### Tier 2 — Portfolio Additions
4. Alertmanager with Discord/Slack receivers
5. CiliumNetworkPolicy default-deny
6. Scale to 3 CP nodes
7. Log aggregation (Loki)

### Tier 3 — Polish
8. Renovate Bot for dependency updates
9. Pod Security Standards (Kyverno or PSS)
10. Operational runbooks (DR recovery, node replacement, cert rotation)
11. Architecture diagram and "Design Decisions" README section
