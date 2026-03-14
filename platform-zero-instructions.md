You are assisting Riccardo Cereghino with **Platform Zero**, a production-grade Kubernetes homelab on Hetzner Cloud. This is a DevOps portfolio project aimed at demonstrating Platform Engineering skills for career opportunities.

## Key Technical Decisions to Respect

- **Talos Linux** over k3s/kubeadm — immutable, API-driven, no SSH. All node config is declarative.
- **Cilium** over Calico — eBPF networking, WireGuard encryption, Hubble observability.
- **Gateway API** over Ingress — forward-looking L7 routing standard.
- **OpenTofu** over Terraform — open-source fork, same HCL syntax.
- **ArgoCD** for platform GitOps — pull-based, in-cluster delivery. Replaced manual `helmfile apply`.
- **SOPS + age** for secret encryption at rest, **KSOPS** for decryption at ArgoCD sync time.
- **Dex** as the central OIDC provider (GitHub connector). Used by ArgoCD, OAuth2-Proxy, and kubectl.
- **CloudNativePG** for managed PostgreSQL — operator-managed, HA-capable database clusters.
- **Crossplane** for infrastructure control plane — declarative cloud resource management from Kubernetes.
- **Coraza WAF** (`platform/waf-chart/`) is **deprecated** — the operational burden of self-managing a WAF (rule tuning, false positives, custom chart maintenance) outweighs the benefits. Cloudflare managed firewall is the recommended approach for new deployments (see ADR-022). The existing deployment remains functional but receives no further investment.

## Repository Layout

```
infrastructure/        -> OpenTofu (.tf files), Hetzner Cloud + Talos bootstrap
infrastructure/packer/ -> Packer image definitions (Talos Linux snapshots)
infrastructure/templates/ -> Talos shell script templates
platform/              -> Helmfile + kustomize + ArgoCD Application manifests
platform/argocd-apps/  -> ArgoCD Application resources (13 total, one per component)
platform/argocd-values.yaml -> ArgoCD Helm values (OIDC, KSOPS, RBAC)
platform/waf-chart/    -> Custom WAF Helm chart (Coraza + Caddy) [deprecated]
scripts/               -> Utilities (upstream-sync.sh, env.sh)
secrets/               -> SOPS-encrypted local dev environment secrets
.github/workflows/     -> CI (lint + validate) and Infra CD (tofu apply)
```

## When Helping With This Project

- Infrastructure changes go in `infrastructure/*.tf`. The codebase owns the full Terraform files (not a module call).
- Platform Helm values are defined in `helmfile.yaml` AND mirrored in the corresponding ArgoCD Application manifest in `platform/argocd-apps/`. When changing Helm values, update both places.
- Raw Kubernetes manifests (HTTPRoutes, RBAC, namespaces, CNPG clusters) go in `platform/` and must be listed in `platform/kustomization.yaml`.
- New SOPS-encrypted secrets must be added to `platform/ksops-generator.yaml` and follow the `*-secrets.yaml` naming pattern.
- The custom WAF chart lives at `platform/waf-chart/` — it's a hand-authored Helm chart, not from a registry. **Deprecated** — do not add new features or rules to this chart.
- Secrets are SOPS+age encrypted in `platform/*-secrets.yaml`. Never add plaintext secrets to git.
- The cluster domain is `cereghino.me`. Services use subdomains (argocd, backstage, dex, hubble, vault, grafana).
- CI validates with: tofu fmt/validate/plan, yamllint, helmfile lint, kubeconform.
- Platform delivery is via ArgoCD — push to `master` and ArgoCD auto-syncs.
- ArgoCD Application manifests in `platform/argocd-apps/` are self-managed via App-of-Apps — `platform-manifests` kustomize Application manages all 12 other manifests. Only `platform-manifests.yaml` itself needs `kubectl apply -f platform/argocd-apps/platform-manifests.yaml` when changed.
- Crossplane Provider resources live in `platform/crossplane-providers.yaml`, managed by the `crossplane-providers` ArgoCD Application. Crossplane core must sync first before providers become active.
- Database clusters (CNPG) are defined as raw manifests in `platform/` (e.g., `vault-db.yaml`).

## Current Priorities (in order)

1. Alertmanager configuration (Discord/Slack receivers)
2. CiliumNetworkPolicy default-deny
3. WAF deprecation — migrate vault.cereghino.me and grafana.cereghino.me to Cloudflare Proxy managed firewall
4. HA control plane (3 CP nodes)
5. Log aggregation (Loki)
6. Renovate Bot for dependency updates

## Style Preferences

- Prefer declarative, GitOps-friendly approaches.
- Use Helm charts where mature ones exist; raw manifests for simple or custom resources.
- Follow the existing naming conventions: kebab-case for Kubernetes resources, snake_case for Terraform variables.
- Keep security posture high: encrypted storage, OIDC auth, Cloudflare Proxy (preferred over self-managed WAF), no static credentials.
- When suggesting changes, consider CI pipeline compatibility (yamllint, kubeconform, helmfile lint).
- When adding new platform components: create an ArgoCD Application manifest, add to helmfile if Helm-based, add routes to kustomization.yaml if web-exposed.
- When adding new namespaces that need privileged PSA: create a namespace manifest in `platform/` with appropriate labels.
