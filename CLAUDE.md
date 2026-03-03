# DevOps Monorepo

Infrastructure-as-Code repository managing a Kubernetes cluster on Hetzner Cloud.

## Directory Layout

- `infrastructure/` — OpenTofu (Terraform) configs for Hetzner Cloud, Talos Linux cluster, networking, storage, and Helm-bootstrapped components
- `infrastructure/packer/` — Packer image definitions (amd64/arm64)
- `infrastructure/templates/` — Talos shell script templates
- `platform/` — Helmfile-managed platform services (external-dns, dex, oauth2-proxy, vaultwarden, velero, prometheus-stack, WAF)
- `platform/waf-chart/` — Custom Helm chart for WAF
- `scripts/` — Utility scripts (upstream-sync.sh for tracking upstream module changes)
- `.github/workflows/` — CI (lint, plan, validate) and CD (auto-apply on master)

## Tech Stack

- **IaC**: OpenTofu (Terraform-compatible), HCloud + AWS (S3) + Talos + Helm providers
- **Cluster OS**: Talos Linux (managed via `talosctl`)
- **Networking**: Cilium CNI, Gateway API (HTTPRoute)
- **Platform**: Helmfile, Helm 3
- **Auth**: Dex (GitHub OIDC connector) + OAuth2 Proxy
- **Monitoring**: kube-prometheus-stack (Grafana + Prometheus)
- **Backups**: Velero with S3 backend
- **Storage**: Longhorn
- **DNS**: external-dns with Cloudflare
- **CI/CD**: GitHub Actions

## Key Commands

```bash
# Infrastructure
cd infrastructure && tofu init && tofu plan    # Plan changes
cd infrastructure && tofu fmt -check           # Check formatting (CI runs this)
cd infrastructure && tofu validate             # Validate configs

# Platform
cd platform && helmfile lint                   # Lint Helm releases
cd platform && helmfile diff                   # Preview changes
cd platform && helmfile template | kubeconform -strict -summary -ignore-missing-schemas  # Validate manifests

# YAML linting (from repo root)
yamllint -c .yamllint platform/

# Upstream sync
./scripts/upstream-sync.sh                     # Diff against upstream main
./scripts/upstream-sync.sh apply               # Generate patch file
```

## Conventions

- OpenTofu files must pass `tofu fmt -check` before merge
- YAML files must pass `yamllint` with the repo's `.yamllint` config
- Secrets are stored in Kubernetes Secrets manifests (not committed with real values)
- Infrastructure CD auto-applies on push to `master` (only for `infrastructure/` path changes)
- Upstream Terraform module from `hcloud-k8s/terraform-hcloud-kubernetes` — use `scripts/upstream-sync.sh` to track drift
