# Project TODOs & Future Improvements

This document tracks planned features, technical debt, and architectural improvements for the cluster.

## Completed

- [x] **SOPS + age Secret Encryption**: Secrets are encrypted at rest in git with SOPS+age. KSOPS decrypts them at ArgoCD sync time.
- [x] **ArgoCD GitOps**: Pull-based platform delivery via ArgoCD with 13 Application resources, automated sync, self-heal, and pruning. Replaced the manual `helmfile apply` workflow.
- [x] **ArgoCD OIDC SSO**: ArgoCD UI exposed at `argocd.cereghino.me` with Dex SSO (GitHub OIDC), email-based RBAC.
- [x] **Pod Security Admission**: Privileged PSA labels for monitoring, velero, and longhorn namespaces (node-exporter, velero node-agent, and longhorn require host access).
- [x] **cert-manager**: TLS certificate management via ACME with Gateway API integration, deployed as a dedicated ArgoCD Application.
- [x] **Crossplane**: Infrastructure control plane with dedicated providers (Kubernetes, Helm, AWS, Hetzner Cloud) split into separate ArgoCD Applications (crossplane + crossplane-providers).
- [x] **Longhorn**: Distributed block storage deployed as a platform-level ArgoCD Application alongside Hetzner CSI.
- [x] **CloudNativePG**: CNPG PostgreSQL cluster (3 replicas) backing Vaultwarden, replacing in-process SQLite.
- [x] **Backstage**: Developer portal deployed at `backstage.cereghino.me` with dedicated namespace and ArgoCD Application.
- [x] **Helm-to-Platform Refactor**: Moved Helm deployments (cert-manager, etc.) from infrastructure Terraform to platform layer ArgoCD Applications.
- [x] **ArgoCD App-of-Apps**: ArgoCD Application manifests are self-managed — `platform-manifests` kustomize Application manages all other 12 manifests. Only `platform-manifests.yaml` requires manual `kubectl apply`.
- [x] **Architecture Decision Records**: 30 ADRs written in `docs/adrs/` covering all major infrastructure, networking, security, and platform design decisions.

## Infrastructure & High Availability
- [ ] **Scale Control Plane**: Migrate from 1 Control Plane node to 3 CP nodes to achieve etcd quorum and true API high availability.
- [ ] **Multi-Region/Zone Deployment**: Evaluate distributing worker nodes across different Hetzner locations for fault tolerance.

## Security & Secret Management
- [ ] **Network Policies**: Implement default-deny `CiliumNetworkPolicy` behavior. Lock down namespace-to-namespace communication so exposed services (like WAF/Grafana) cannot unnecessarily reach internal components.
- [ ] **WAF Deprecation**: Migrate vault.cereghino.me and grafana.cereghino.me protection to Cloudflare Proxy managed firewall. Remove the `waf` ArgoCD Application and `platform/waf-chart/` once traffic is re-routed (see ADR-022).

## Platform & GitOps
- [ ] **Renovate / Dependabot**: Setup automated dependency updates for Helm charts, OpenTofu providers, and container images.

## Observability & SRE Operations
- [ ] **Alerting Configuration**: Configure Alertmanager with Slack/Discord/Email receivers. Critical events (Node NotReady, Pod CrashLoopBackOff, Backup Failed) should page the administrator.
- [ ] **Disaster Recovery (DR) Drill**: Document step-by-step instructions for completing a full cluster restoration from S3. Schedule a test to destroy a worker node and recover it, and test a full Velero application restore.
- [ ] **Dashboard Provisioning as Code**: Fully provision Grafana dashboards (like Velero stats, WAF metrics) via ConfigMaps/GitOps rather than manual UI imports.
- [ ] **Log Aggregation**: Evaluate Loki or similar for centralized log collection and querying.
