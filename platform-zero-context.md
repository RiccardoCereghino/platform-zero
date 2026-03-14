# Platform Zero — Project Context

## What This Is

A production-grade Kubernetes homelab on Hetzner Cloud running Talos Linux, fully defined as code. Built as a DevOps/Platform Engineering portfolio project to demonstrate SRE practices and open career opportunities.

**Owner**: Riccardo Cereghino
**Domain**: cereghino.me
**Repository structure**: monorepo with `infrastructure/`, `platform/`, `scripts/`

---

## Infrastructure Layer

**Provisioning**: OpenTofu >= 1.9.0 (Terraform fork), based on `hcloud-k8s/terraform-hcloud-kubernetes` module (full local ownership of .tf files, not a module reference).

**Cloud**: Hetzner Cloud, location `nbg1` (Nuremberg).

**Cluster topology**:
- 1 Control Plane node (CPX22: 2 vCPU, 4GB RAM, 40GB SSD)
- 2 Worker nodes (CPX22 each)
- Single CP — no etcd quorum yet (planned: scale to 3 CP)

**OS**: Talos Linux — immutable, API-managed, no SSH. Custom images built with Packer (AMD64 + ARM64).

**Terraform providers**: hcloud, talos, aws, helm, tls, random, http.

**State backend**: S3 on Hetzner Object Storage, bucket `cereghino-tf-state`, key `k8s/terraform.tfstate`.

**Bootstrap Helm charts** (pre-rendered via `helm_template`, injected as Talos inline manifests):
- Cilium (CNI), hcloud-cloud-controller-manager, hcloud-csi, metrics-server

**Key infrastructure files** (28 .tf files in `infrastructure/`):
- `terraform.tfvars` — cluster sizing, feature flags, versions
- `server.tf` — Hetzner server provisioning
- `talos.tf` / `talos_config.tf` — Talos cluster bootstrap and OS config
- `talos_backup.tf` — hourly etcd backups to S3 with age encryption
- `cilium.tf` — Cilium CNI with WireGuard encryption, Gateway API, Hubble
- `firewall.tf` — Hetzner firewall rules
- `oidc.tf` — Kubernetes API OIDC via dex.cereghino.me
- `sops.tf` — Talos inline manifest for `sops-age-key` Secret in `argocd` namespace

---

## Networking

- **Cilium CNI**: eBPF-based, replaces kube-proxy entirely. WireGuard pod-to-pod encryption enabled. Egress gateway enabled.
- **Gateway API**: Layer 7 routing and TLS termination (not legacy Ingress). 6 HTTPRoutes for all external services.
- **ExternalDNS 1.15.0**: Syncs Gateway API resources to Cloudflare DNS.
- **cert-manager**: Automated Let's Encrypt TLS certificates with Gateway API integration.

---

## Platform Layer

Managed via **ArgoCD** (pull-based GitOps) with 13 Application resources in `platform/argocd-apps/`. Helmfile (`platform/helmfile.yaml`) defines Helm values and is used for CI validation; ArgoCD Applications mirror the values for deployment.

**App-of-Apps pattern**: `platform-manifests` is the root Application — it manages all other 12 ArgoCD Application manifests via kustomize (`platform/kustomization.yaml`). Only `platform-manifests.yaml` itself requires manual `kubectl apply` (to avoid circular self-management).

### ArgoCD Applications

| Application | Type | Namespace | Source |
|-------------|------|-----------|--------|
| platform-manifests | Kustomize | (multi-ns) | `platform/` directory via kustomize |
| backstage | Helm | backstage | backstage.github.io |
| cert-manager | Helm | cert-manager | charts.jetstack.io |
| crossplane | Helm | crossplane-system | crossplane-stable |
| crossplane-providers | Kustomize | crossplane-system | git repo `platform/crossplane-providers.yaml` |
| dex | Helm | auth | charts.dexidp.io |
| external-dns | Helm | external-dns | kubernetes-sigs.github.io |
| kube-prometheus-stack | Helm | monitoring | prometheus-community.github.io |
| longhorn | Helm | longhorn-system | charts.longhorn.io |
| oauth2-proxy | Helm | kube-system | oauth2-proxy.github.io |
| vaultwarden | Helm | vault | guerzon.github.io |
| velero | Helm | velero | vmware-tanzu.github.io |
| waf | Helm (custom) | security | git repo `platform/waf-chart/` — **deprecated** |
| argocd | Helm (via helmfile) | argocd | argoproj.github.io (managed by helmfile, not self-managed) |

### Exposed Services

| Service | Domain | Protection |
|---------|--------|------------|
| ArgoCD | argocd.cereghino.me | Dex SSO (GitHub OIDC) |
| Backstage | backstage.cereghino.me | Direct |
| Dex | dex.cereghino.me | Direct (OIDC issuer) |
| Hubble UI | hubble.cereghino.me | OAuth2-Proxy (GitHub OIDC) |
| Vaultwarden | vault.cereghino.me | Coraza WAF (deprecated — see ADR-022) |
| Grafana | grafana.cereghino.me | Coraza WAF (deprecated — see ADR-022) |

### Security Stack

- **Dex**: OIDC issuer backed by GitHub OAuth2. Static clients: `oauth2-proxy`, `kubernetes-cli`, `argocd`.
- **OAuth2-Proxy**: Protects Hubble UI, email-based access control, PKCE S256.
- **Coraza WAF**: Custom Helm chart (`platform/waf-chart/`), Caddy + Coraza with OWASP CRS. Proxies to Vaultwarden and Grafana. Rule exclusions for SQLi/XSS/RCE false positives on Vaultwarden API and Grafana query API. **Deprecated** (ADR-022) — Cloudflare managed firewall recommended for new deployments; this chart receives no further investment.
- **OIDC kubeconfig**: kubectl auth flows through Dex -> GitHub, no static tokens.
- **ArgoCD RBAC**: email-based role mapping via Dex OIDC (`riccardo.cereghino@gmail.com` -> `role:admin`).

### Secret Management

- **SOPS + age**: All Kubernetes secrets (`platform/*-secrets.yaml`) are SOPS-encrypted in git.
- **KSOPS**: Kustomize exec plugin in ArgoCD repo-server decrypts secrets at sync time.
- **Key provisioning**: age private key is stored as a Kubernetes Secret (`sops-age-key` in `argocd` namespace), provisioned via Terraform as a Talos inline manifest (available before ArgoCD starts).
- **KSOPS init container**: `viaductoss/ksops:v4.3.2` copies `ksops` + `kustomize` binaries into the repo-server. KSOPS v4+ embeds the SOPS library (no standalone `sops` binary).
- **Encrypted files**: dex-secrets, oauth2-proxy-secrets, grafana-secrets, vault-secrets (4 files).

### Storage & Backup

- **Hetzner CSI**: LUKS-encrypted volumes with Retain policy (infrastructure-level bootstrap).
- **Longhorn**: Distributed block storage (platform-level ArgoCD Application).
- **Etcd backups**: Hourly CronJob -> Hetzner S3 (`cereghino-infra-backups`), age X25519 encrypted.
- **Velero**: Kubernetes manifest + PV backup to S3 (prefix: `velero/`), node-agent enabled.

### Database

- **CloudNativePG (CNPG)**: PostgreSQL cluster (3 replicas) backing Vaultwarden (`vault-db.yaml`).

### Observability

- **kube-prometheus-stack**: Prometheus + Grafana (admin credentials in SOPS-encrypted secret).
- **Cilium Hubble**: Network flow visualization, UI behind OAuth2-Proxy.
- **No alerting configured yet** — Alertmanager has no receivers.

### Pod Security

- `monitoring`, `velero`, and `longhorn-system` namespaces have `pod-security.kubernetes.io/enforce: privileged` labels (required for node-exporter, velero node-agent, and longhorn DaemonSets).
- Namespace manifests are managed via kustomize (`platform/*-namespace.yaml`).

---

## CI/CD

### ci.yaml (PR + push to master)
**Infrastructure job**: `tofu fmt -check` -> `tofu init` -> `tofu validate` -> `tofu plan` (comments plan on PRs).
**Platform job**: `yamllint` -> `helmfile lint` -> `helmfile template` -> `kubeconform -strict`.

### cd-infra.yaml (push to master, path: infrastructure/**)
Runs `tofu init` -> `tofu apply -auto-approve`. Environment: Production.

### Platform CD (ArgoCD)
ArgoCD runs in-cluster and auto-syncs all 13 Applications from the `master` branch. No GitHub Actions workflow for platform deployment — ArgoCD polls the git repo and reconciles automatically.

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
- No log aggregation (no Loki or equivalent)
- Coraza WAF is deprecated (ADR-022) — vault.cereghino.me and grafana.cereghino.me still route through it; migration to Cloudflare Proxy pending
- Only `platform-manifests.yaml` requires manual `kubectl apply` (all other 12 Application manifests are self-managed via App-of-Apps)

---

## Roadmap (from TODO.md)

### Tier 1 — Next Steps
1. Alertmanager with Discord/Slack receivers
2. CiliumNetworkPolicy default-deny
3. WAF deprecation — migrate to Cloudflare Proxy managed firewall

### Tier 2 — Portfolio Additions
4. Scale to 3 CP nodes
5. Log aggregation (Loki)
6. Renovate Bot for dependency updates

### Tier 3 — Polish
7. Operational runbooks (DR recovery, node replacement, cert rotation)
8. Dashboard provisioning as code (Grafana dashboards via ConfigMaps/GitOps)
