# Project TODOs & Future Improvements

This document tracks planned features, technical debt, and architectural improvements for the cluster.

## Infrastructure & High Availability
- [ ] **Scale Control Plane**: Migrate from 1 Control Plane node to 3 CP nodes to achieve etcd quorum and true API high availability.
- [ ] **Multi-Region/Zone Deployment**: Evaluate distributing worker nodes across different Hetzner locations for fault tolerance.

## Security & Secret Management
- [ ] **Declarative Secrets**: Integrate External Secrets Operator (ESO) + 1Password Connect, or Mozilla SOPS. Currently, secrets are manually created in the cluster before `helmfile apply`.
- [ ] **Network Policies**: Implement default-deny `CiliumNetworkPolicy` behavior. Lock down namespace-to-namespace communication so exposed services (like WAF/Grafana) cannot unnecessarily reach internal components.
- [ ] **WAF Tuning**: Review and tune Coraza WAF OWASP Core Rule Set (CRS) to ensure no false positives are blocking legitimate Vaultwarden syncs or Grafana queries.

## Platform & GitOps
- [ ] **GitOps Migration**: Move away from manual `helmfile apply` executions. Adopt FluxCD or ArgoCD to pull configurations directly from this repository, making Git the undisputed source of truth.
- [ ] **Renovate / Dependabot**: Setup automated dependency updates for Helm charts, OpenTofu providers, and container images.

## Observability & SRE Operations
- [ ] **Alerting Configuration**: Configure Alertmanager with Slack/Discord/Email receivers. Critical events (Node NotReady, Pod CrashLoopBackOff, Backup Failed) should page the administrator.
- [ ] **Disaster Recovery (DR) Drill**: Document step-by-step instructions for completing a full cluster restoration from S3. Schedule a test to destroy a worker node and recover it, and test a full Velero application restore.
- [ ] **Dashboard Provisioning as Code**: Fully provision Grafana dashboards (like Velero stats, WAF metrics) via ConfigMaps/GitOps rather than manual UI imports.
