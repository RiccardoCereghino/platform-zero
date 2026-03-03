You are assisting Riccardo Cereghino with **Platform Zero**, a production-grade Kubernetes homelab on Hetzner Cloud. This is a DevOps portfolio project aimed at demonstrating Platform Engineering skills for career opportunities.

## Key Technical Decisions to Respect

- **Talos Linux** over k3s/kubeadm — immutable, API-driven, no SSH. All node config is declarative.
- **Cilium** over Calico — eBPF networking, WireGuard encryption, Hubble observability.
- **Gateway API** over Ingress — forward-looking L7 routing standard.
- **OpenTofu** over Terraform — open-source fork, same HCL syntax.
- **Helmfile** for platform orchestration (migration to ArgoCD planned).
- **1Password CLI** via direnv for local secret injection.

## Repository Layout

```
infrastructure/   → OpenTofu (.tf files), Hetzner Cloud + Talos bootstrap
platform/         → Helmfile + Kubernetes manifests, all platform services
apps/             → Application workloads (future)
scripts/          → Utilities (upstream-sync.sh)
.github/workflows → CI (lint + validate) and CD (tofu apply)
```

## When Helping With This Project

- Infrastructure changes go in `infrastructure/*.tf`. The codebase owns the full Terraform files (not a module call).
- Platform changes go in `platform/`. Helm values are inline in `helmfile.yaml`, raw manifests are sibling YAML files.
- The custom WAF chart lives at `platform/waf-chart/` — it's a hand-authored Helm chart, not from a registry.
- Secrets are currently plaintext in `platform/*-secrets.yaml` — this is the top priority to fix. Don't add more plaintext secrets.
- The cluster domain is `cereghino.me`. Services use subdomains (dex, hubble, vault, grafana).
- CI validates with: tofu fmt/validate/plan, yamllint, helmfile lint, kubeconform.
- There is no platform CD yet — `helmfile apply` is manual from a local machine.

## Current Priorities (in order)

1. Move secrets out of git (External Secrets Operator + 1Password Connect, or SOPS)
2. ArgoCD for platform GitOps
3. Platform CD GitHub Actions workflow
4. Alertmanager configuration
5. CiliumNetworkPolicy default-deny
6. HA control plane (3 CP nodes)

## Style Preferences

- Prefer declarative, GitOps-friendly approaches.
- Use Helm charts where mature ones exist; raw manifests for simple or custom resources.
- Follow the existing naming conventions: kebab-case for Kubernetes resources, snake_case for Terraform variables.
- Keep security posture high: encrypted storage, OIDC auth, WAF, no static credentials.
- When suggesting changes, consider CI pipeline compatibility (yamllint, kubeconform, helmfile lint).
