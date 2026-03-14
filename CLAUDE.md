# DevOps Monorepo

Infrastructure-as-Code repository managing a Kubernetes cluster on Hetzner Cloud.

## Directory Layout

- `infrastructure/` — OpenTofu (Terraform) configs for Hetzner Cloud, Talos Linux cluster, networking, storage, and pre-rendered Helm bootstrap manifests
- `infrastructure/packer/` — Packer image definitions for Talos Linux snapshots (amd64/arm64)
- `infrastructure/templates/` — Talos shell script templates (upgrade, apply-config, health checks)
- `platform/` — Platform layer: Helmfile for Helm release definitions, kustomize for raw manifests + KSOPS secret decryption
- `platform/argocd-apps/` — ArgoCD Application manifests (one per platform component, 13 total)
- `platform/argocd-values.yaml` — ArgoCD Helm values (OIDC, KSOPS, RBAC)
- `platform/waf-chart/` — Custom Helm chart for Coraza WAF (Caddy-based reverse proxy) — **deprecated, retained but not actively maintained**
- `scripts/` — Utility scripts (upstream-sync.sh, env.sh)
- `.github/workflows/` — CI (lint, plan, validate) and Infrastructure CD (auto-apply on master)
- `secrets/` — SOPS-encrypted local environment secrets

## Tech Stack

- **IaC**: OpenTofu (Terraform-compatible); providers: hcloud, aws, talos, helm, http, tls, random
- **Cluster OS**: Talos Linux (managed via `talosctl`)
- **Networking**: Cilium CNI (WireGuard encryption, kube-proxy replacement), Gateway API (6 HTTPRoutes)
- **GitOps**: ArgoCD (pull-based, in-cluster) with KSOPS for SOPS+age secret decryption
- **Platform**: Helmfile (12 releases, defines Helm values), ArgoCD (deploys them)
- **Auth**: Dex (GitHub OIDC connector) + OAuth2 Proxy; ArgoCD uses Dex for SSO
- **Secrets**: SOPS + age encryption at rest (`.sops.yaml` config at repo root), KSOPS decryption at sync time
- **TLS**: cert-manager with ACME and Gateway API integration
- **Monitoring**: kube-prometheus-stack (Grafana + Prometheus)
- **Backups**: Velero with S3 backend; etcd backups via Talos CronJob to S3
- **Storage**: Hetzner CSI with LUKS encryption (infrastructure-level), Longhorn distributed block storage (platform-level)
- **Database**: CloudNativePG (CNPG) PostgreSQL cluster for Vaultwarden (3 replicas)
- **DNS**: external-dns with Cloudflare
- **Security**: Coraza WAF (Caddy) — deployed but **deprecated** (see ADR-022); Cloudflare managed firewall recommended for future deployments
- **CI/CD**: GitHub Actions (CI + Infra CD), ArgoCD (Platform CD)
- **Developer Portal**: Backstage at `backstage.cereghino.me`
- **Infrastructure Control Plane**: Crossplane with providers for Kubernetes, Helm, AWS, and Hetzner Cloud

## Key Commands

```bash
# Infrastructure
cd infrastructure && tofu init && tofu plan    # Plan changes
cd infrastructure && tofu fmt -check           # Check formatting (CI runs this)
cd infrastructure && tofu validate             # Validate configs

# Platform (CI validation)
cd platform && helmfile lint                   # Lint Helm releases
cd platform && helmfile diff                   # Preview changes
cd platform && helmfile template | kubeconform -strict -summary -ignore-missing-schemas  # Validate manifests

# Platform (deployment is via ArgoCD — push to master triggers auto-sync)
# Manual helmfile apply is only needed for bootstrapping or emergency fixes:
cd platform && helmfile apply --selector name=argocd  # Bootstrap/update ArgoCD itself

# ArgoCD Application management (App-of-Apps: most apps are self-managed via platform-manifests)
# Only platform-manifests.yaml needs manual apply — it manages all other 12 Applications via kustomize
kubectl apply -f platform/argocd-apps/platform-manifests.yaml  # Bootstrap / update the root app
# Individual apps can still be applied out-of-band for emergency fixes:
kubectl apply -f platform/argocd-apps/dex.yaml   # Apply a single Application (out-of-band)

# YAML linting (from repo root)
yamllint -c .yamllint platform/

# Upstream sync
./scripts/upstream-sync.sh                     # Diff against upstream main
./scripts/upstream-sync.sh apply               # Generate patch file

# Local secrets
source scripts/env.sh                          # Decrypt and load SOPS secrets into shell
```

## ArgoCD Architecture

- **9 active ArgoCD Applications** in `platform/argocd-apps/`: cert-manager, dex, external-dns, kube-prometheus-stack, oauth2-proxy, platform-manifests, vaultwarden, velero, waf
- **4 disabled Applications** (files retained, commented out in kustomization.yaml — see ADR-031): backstage, crossplane, crossplane-providers, longhorn
- **platform-manifests** Application: App-of-Apps root — manages raw K8s manifests AND all other active ArgoCD Application manifests via kustomize (`platform/kustomization.yaml`). Includes HTTPRoutes, RBAC, namespace configs, KSOPS-decrypted secrets, and CNPG database clusters. `platform-manifests.yaml` itself is excluded from kustomize to avoid circular self-management and must be applied manually.
- **Helm-based Applications**: each mirrors values from `helmfile.yaml` in an ArgoCD Application with `valuesObject`
- **Self-heal + auto-prune**: all Applications have `automated.selfHeal: true` and `automated.prune: true`
- **Private repo access**: SSH deploy key for `git@github.com:RiccardoCereghino/platform-zero.git`
- **KSOPS flow**: ArgoCD repo-server has an init container (`viaductoss/ksops:v4.3.2`) that copies `ksops` + `kustomize` binaries; the `sops-age-key` Secret (provisioned via Terraform as a Talos inline manifest) is mounted for decryption
- **ArgoCD UI**: exposed at `argocd.cereghino.me` via HTTPRoute, SSO via Dex (GitHub OIDC)

## Infrastructure Bootstrap

The infrastructure layer pre-renders core system Helm charts via `helm_template` data sources and injects them as Talos inline manifests during cluster initialization. These are **not** `helm_release` resources — they are one-time bootstrap manifests:

- **Cilium** — CNI with WireGuard encryption
- **hcloud-cloud-controller-manager** — Hetzner Cloud integration, load balancing
- **hcloud-csi** — Storage provisioning with LUKS encryption
- **metrics-server** — Kubernetes resource metrics

Post-bootstrap, the platform layer (Helmfile + ArgoCD) manages all higher-level applications.

## Conventions

- OpenTofu files must pass `tofu fmt -check` before merge
- YAML files must pass `yamllint` with the repo's `.yamllint` config
- Secrets are SOPS+age encrypted in git (`platform/*-secrets.yaml`), decrypted by KSOPS at ArgoCD sync time
- Local dev secrets use `secrets/*.yaml` pattern (whole-file encryption)
- Infrastructure CD auto-applies on push to `master` (only for `infrastructure/` path changes)
- Platform CD is GitOps via ArgoCD — push to `master` and ArgoCD auto-syncs
- ArgoCD Application manifests (`platform/argocd-apps/`) are self-managed via App-of-Apps — `platform-manifests` kustomize Application manages all other 12 manifests. Only `platform-manifests.yaml` itself requires `kubectl apply -f platform/argocd-apps/platform-manifests.yaml` when changed.
- Upstream Terraform module from `hcloud-k8s/terraform-hcloud-kubernetes` — use `scripts/upstream-sync.sh` to track drift
- Namespaces requiring privileged PSA (monitoring, velero, longhorn) have explicit namespace manifests in `platform/`
- Crossplane Provider manifests live in `platform/crossplane-providers.yaml` (managed by crossplane-providers ArgoCD Application); Crossplane core must sync first before providers become active
- Gateway API HTTPRoutes in `platform/` define external routing; WAF currently proxies vault and grafana traffic (WAF deprecated — see ADR-022)
