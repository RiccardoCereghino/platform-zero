# DevOps Monorepo

Infrastructure-as-Code repository managing a Kubernetes cluster on Hetzner Cloud.

## Directory Layout

- `infrastructure/` — OpenTofu (Terraform) configs for Hetzner Cloud, Talos Linux cluster, networking, storage, and Helm-bootstrapped components
- `infrastructure/packer/` — Packer image definitions (amd64/arm64)
- `infrastructure/templates/` — Talos shell script templates
- `platform/` — Platform layer: Helmfile for Helm release definitions, kustomize for raw manifests + KSOPS secret decryption
- `platform/argocd-apps/` — ArgoCD Application manifests (one per platform component)
- `platform/argocd-values.yaml` — ArgoCD Helm values (OIDC, KSOPS, RBAC)
- `platform/waf-chart/` — Custom Helm chart for WAF
- `scripts/` — Utility scripts (upstream-sync.sh for tracking upstream module changes)
- `.github/workflows/` — CI (lint, plan, validate) and Infrastructure CD (auto-apply on master)

## Tech Stack

- **IaC**: OpenTofu (Terraform-compatible), HCloud + AWS (S3) + Talos + Helm providers
- **Cluster OS**: Talos Linux (managed via `talosctl`)
- **Networking**: Cilium CNI, Gateway API (HTTPRoute)
- **GitOps**: ArgoCD (pull-based, in-cluster) with KSOPS for SOPS+age secret decryption
- **Platform**: Helmfile (defines Helm values), ArgoCD (deploys them)
- **Auth**: Dex (GitHub OIDC connector) + OAuth2 Proxy; ArgoCD uses Dex for SSO
- **Secrets**: SOPS + age encryption at rest, KSOPS decryption at sync time
- **Monitoring**: kube-prometheus-stack (Grafana + Prometheus)
- **Backups**: Velero with S3 backend
- **Storage**: Hetzner CSI with LUKS encryption
- **DNS**: external-dns with Cloudflare
- **CI/CD**: GitHub Actions (CI + Infra CD), ArgoCD (Platform CD)

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

# ArgoCD Application management (initial setup or out-of-band fixes)
kubectl apply -f platform/argocd-apps/           # Apply all ArgoCD Applications
kubectl apply -f platform/argocd-apps/dex.yaml   # Apply a single Application

# YAML linting (from repo root)
yamllint -c .yamllint platform/

# Upstream sync
./scripts/upstream-sync.sh                     # Diff against upstream main
./scripts/upstream-sync.sh apply               # Generate patch file
```

## ArgoCD Architecture

- **8 ArgoCD Applications** in `platform/argocd-apps/`: dex, external-dns, kube-prometheus-stack, oauth2-proxy, platform-manifests, vaultwarden, velero, waf
- **platform-manifests** Application: manages raw K8s manifests via kustomize (`platform/kustomization.yaml`), including HTTPRoutes, RBAC, namespace configs, and KSOPS-decrypted secrets
- **Helm-based Applications**: each mirrors values from `helmfile.yaml` in an ArgoCD Application with `valuesObject`
- **Self-heal + auto-prune**: all Applications have `automated.selfHeal: true` and `automated.prune: true`
- **Private repo access**: SSH deploy key for `git@github.com:RiccardoCereghino/platform-zero.git`
- **KSOPS flow**: ArgoCD repo-server has an init container (`viaductoss/ksops:v4.3.2`) that copies `ksops` + `kustomize` binaries; the `sops-age-key` Secret (provisioned via Terraform as a Talos inline manifest) is mounted for decryption
- **ArgoCD UI**: exposed at `argocd.cereghino.me` via HTTPRoute, SSO via Dex (GitHub OIDC)

## Conventions

- OpenTofu files must pass `tofu fmt -check` before merge
- YAML files must pass `yamllint` with the repo's `.yamllint` config
- Secrets are SOPS+age encrypted in git (`platform/*-secrets.yaml`), decrypted by KSOPS at ArgoCD sync time
- Infrastructure CD auto-applies on push to `master` (only for `infrastructure/` path changes)
- Platform CD is GitOps via ArgoCD — push to `master` and ArgoCD auto-syncs
- ArgoCD Application manifests (`platform/argocd-apps/`) are NOT self-managed — apply with `kubectl apply` when changed
- Upstream Terraform module from `hcloud-k8s/terraform-hcloud-kubernetes` — use `scripts/upstream-sync.sh` to track drift
- Namespaces requiring privileged PSA (monitoring, velero) have explicit namespace manifests in `platform/`
