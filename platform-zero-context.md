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
- `sops.tf` — Talos inline manifest for `sops-age-key` Secret in `argocd` namespace

---

## Networking

- **Cilium CNI**: eBPF-based, replaces kube-proxy entirely. WireGuard pod-to-pod encryption enabled. Egress gateway enabled.
- **Gateway API**: Layer 7 routing and TLS termination (not legacy Ingress).
- **ExternalDNS 1.15.0**: Syncs Gateway API resources to Cloudflare DNS.
- **Cert-Manager**: Automated Let's Encrypt TLS certificates.

---

## Platform Layer

Managed via **ArgoCD** (pull-based GitOps) with 8 Application resources in `platform/argocd-apps/`. Helmfile (`platform/helmfile.yaml`) defines Helm values and is used for CI validation; ArgoCD Applications mirror the values for deployment.

### ArgoCD Applications

| Application | Type | Namespace | Source |
|-------------|------|-----------|--------|
| platform-manifests | Kustomize | (multi-ns) | `platform/` directory via kustomize |
| dex | Helm | auth | charts.dexidp.io |
| external-dns | Helm | external-dns | kubernetes-sigs.github.io |
| oauth2-proxy | Helm | kube-system | oauth2-proxy.github.io |
| vaultwarden | Helm | vault | guerzon.github.io |
| velero | Helm | velero | vmware-tanzu.github.io |
| kube-prometheus-stack | Helm | monitoring | prometheus-community.github.io |
| waf | Helm (custom) | security | git repo `platform/waf-chart/` |
| argocd | Helm (via helmfile) | argocd | argoproj.github.io (managed by helmfile, not self-managed) |

### Exposed Services

| Service | Domain | Protection |
|---------|--------|------------|
| ArgoCD | argocd.cereghino.me | Dex SSO (GitHub OIDC) |
| Dex | dex.cereghino.me | Direct (OIDC issuer) |
| Hubble UI | hubble.cereghino.me | OAuth2-Proxy (GitHub OIDC) |
| Vaultwarden | vault.cereghino.me | Coraza WAF |
| Grafana | grafana.cereghino.me | Coraza WAF |

### Security Stack

- **Dex**: OIDC issuer backed by GitHub OAuth2. Static clients: `oauth2-proxy`, `kubernetes-cli`, `argocd`.
- **OAuth2-Proxy**: Protects Hubble UI, email-based access control, PKCE S256.
- **Coraza WAF**: Custom Helm chart (`platform/waf-chart/`), Caddy + Coraza with OWASP CRS. Proxies to Vaultwarden and Grafana. Rule exclusions: SQLi (942100) for Vaultwarden API and Grafana query API.
- **OIDC kubeconfig**: kubectl auth flows through Dex -> GitHub, no static tokens.
- **ArgoCD RBAC**: email-based role mapping via Dex OIDC (`riccardo.cereghino@gmail.com` -> `role:admin`).

### Secret Management

- **SOPS + age**: All Kubernetes secrets (`platform/*-secrets.yaml`) are SOPS-encrypted in git.
- **KSOPS**: Kustomize exec plugin in ArgoCD repo-server decrypts secrets at sync time.
- **Key provisioning**: age private key is stored as a Kubernetes Secret (`sops-age-key` in `argocd` namespace), provisioned via Terraform as a Talos inline manifest (available before ArgoCD starts).
- **KSOPS init container**: `viaductoss/ksops:v4.3.2` copies `ksops` + `kustomize` binaries into the repo-server. KSOPS v4+ embeds the SOPS library (no standalone `sops` binary).

### Storage & Backup

- **Hetzner CSI**: `vault-storage` StorageClass with LUKS encryption, Retain policy.
- **Etcd backups**: Hourly CronJob -> Hetzner S3 (`cereghino-infra-backups`), age X25519 encrypted.
- **Velero**: Kubernetes manifest + PV backup to S3 (prefix: `velero/`), node-agent enabled.

### Observability

- **kube-prometheus-stack**: Prometheus + Grafana (admin credentials in SOPS-encrypted secret).
- **Cilium Hubble**: Network flow visualization, UI behind OAuth2-Proxy.
- **No alerting configured yet** — Alertmanager has no receivers.

### Pod Security

- `monitoring` and `velero` namespaces have `pod-security.kubernetes.io/enforce: privileged` labels (required for node-exporter and velero node-agent DaemonSets).
- Namespace manifests are managed via kustomize (`platform/monitoring-namespace.yaml`, `platform/velero-namespace.yaml`).

---

## CI/CD

### ci.yaml (PR + push to master)
**Infrastructure job**: `tofu fmt -check` -> `tofu init` -> `tofu validate` -> `tofu plan` (comments plan on PRs).
**Platform job**: `yamllint` -> `helmfile lint` -> `helmfile template` -> `kubeconform -strict`.

### cd-infra.yaml (push to master, path: infrastructure/**)
Runs `tofu init` -> `tofu apply -auto-approve`. Environment: Production.

### Platform CD (ArgoCD)
ArgoCD runs in-cluster and auto-syncs all 8 Applications from the `master` branch. No GitHub Actions workflow for platform deployment — ArgoCD polls the git repo and reconciles automatically.

---

## Local Development

**Secret management**: SOPS+age encrypted `secrets/local.env.yaml`, loaded via `source scripts/env.sh`.

**Upstream sync**: `scripts/upstream-sync.sh` tracks changes from the upstream Terraform module, generates patch files.

---

## Known Issues & Technical Debt

### Architectural Gaps
- Single control plane (no HA, no etcd quorum)
- No alerting (Prometheus without Alertmanager receivers)
- No default-deny network policies (Cilium capable but unenforced)
- WAF rule exclusions undocumented
- ArgoCD Application manifests are not self-managed (applied manually via `kubectl apply`)

---

## Roadmap (from TODO.md)

### Tier 1 — Next Steps
1. ArgoCD App-of-Apps (self-manage Application manifests)
2. Alertmanager with Discord/Slack receivers
3. CiliumNetworkPolicy default-deny

### Tier 2 — Portfolio Additions
4. Scale to 3 CP nodes
5. Log aggregation (Loki)
6. Renovate Bot for dependency updates

### Tier 3 — Polish
7. Pod Security Standards (Kyverno or PSS enforcement across all namespaces)
8. Operational runbooks (DR recovery, node replacement, cert rotation)
9. Architecture diagram and "Design Decisions" README section
