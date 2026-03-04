# Project TODOs & Future Improvements

This document tracks planned features, technical debt, and architectural improvements for the cluster.

## Completed

- [x] **SOPS + age Secret Encryption**: Secrets are encrypted at rest in git with SOPS+age. KSOPS decrypts them at ArgoCD sync time.
- [x] **ArgoCD GitOps**: Pull-based platform delivery via ArgoCD with 8 Application resources, automated sync, self-heal, and pruning. Replaced the manual `helmfile apply` workflow.
- [x] **ArgoCD OIDC SSO**: ArgoCD UI exposed at `argocd.cereghino.me` with Dex SSO (GitHub OIDC), email-based RBAC.
- [x] **Pod Security Admission**: Privileged PSA labels for monitoring and velero namespaces (node-exporter and velero node-agent require host access).

## Infrastructure & High Availability
- [ ] **Scale Control Plane**: Migrate from 1 Control Plane node to 3 CP nodes to achieve etcd quorum and true API high availability.
- [ ] **Multi-Region/Zone Deployment**: Evaluate distributing worker nodes across different Hetzner locations for fault tolerance.

## Security & Secret Management
- [ ] **Network Policies**: Implement default-deny `CiliumNetworkPolicy` behavior. Lock down namespace-to-namespace communication so exposed services (like WAF/Grafana) cannot unnecessarily reach internal components.
- [ ] **WAF Tuning**: Review and tune Coraza WAF OWASP Core Rule Set (CRS) to ensure no false positives are blocking legitimate Vaultwarden syncs or Grafana queries.

## Platform & GitOps
- [ ] **ArgoCD App-of-Apps**: Consider managing ArgoCD Application manifests via an App-of-Apps pattern so they are self-managed from git (currently applied manually via `kubectl apply`).
- [ ] **Renovate / Dependabot**: Setup automated dependency updates for Helm charts, OpenTofu providers, and container images.
- [ ] **KSOPS sops binary review**: KSOPS v4.3.2 embeds the SOPS Go library and does not ship a standalone `sops` binary. Verify this is the intended behavior and document any implications for debugging.

## Observability & SRE Operations
- [ ] **Alerting Configuration**: Configure Alertmanager with Slack/Discord/Email receivers. Critical events (Node NotReady, Pod CrashLoopBackOff, Backup Failed) should page the administrator.
- [ ] **Disaster Recovery (DR) Drill**: Document step-by-step instructions for completing a full cluster restoration from S3. Schedule a test to destroy a worker node and recover it, and test a full Velero application restore.
- [ ] **Dashboard Provisioning as Code**: Fully provision Grafana dashboards (like Velero stats, WAF metrics) via ConfigMaps/GitOps rather than manual UI imports.
