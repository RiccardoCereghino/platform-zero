# SRE Homelab Cluster

Welcome to my Kubernetes homelab. This repository contains the declarative infrastructure and platform configuration for a highly resilient, secure, and observable Kubernetes cluster running on Hetzner Cloud.

Built with Site Reliability Engineering (SRE) principles in mind, this project goes beyond a simple deployment by incorporating immutable infrastructure, advanced layer 7 networking, automated encrypted backups, GitOps delivery, and identity-aware proxying.

## Architecture & Core Components

### 1. Infrastructure (OpenTofu + Talos Linux)
The underlying infrastructure is provisioned on Hetzner Cloud using OpenTofu. We use **Talos Linux** as the operating system — an immutable, specialized OS designed explicitly for Kubernetes.
- **Node Topology**: 1 Control Plane, 2 Worker nodes (configured in `infrastructure/terraform.tfvars`).
- **Storage**: Hetzner CSI with LUKS-encrypted volumes for stateful workloads; Longhorn for distributed block storage.
- **State Management**: OpenTofu state is securely stored in a remote S3 backend.
- **Custom Images**: Talos Linux snapshots built via Packer for both amd64 and arm64 architectures.

### 2. Networking (Cilium + Gateway API)
We bypass legacy `kube-proxy` and standard Ingress controllers in favor of a modern networking stack.
- **Cilium CNI**: High-performance eBPF-based overlay networking with kube-proxy replacement.
- **Gateway API**: Layer 7 traffic routing and TLS termination via HTTPRoutes (6 routes managing all external access).
- **Pod-to-Pod Encryption**: Transparent WireGuard encryption for all intra-cluster traffic.
- **ExternalDNS**: Automated DNS record creation on Cloudflare from Gateway API resources.
- **cert-manager**: Automated Let's Encrypt TLS certificate provisioning with Gateway API integration.

### 3. GitOps & Delivery (ArgoCD + KSOPS)
Platform delivery uses a pull-based GitOps model. ArgoCD runs in-cluster and continuously reconciles the desired state from this repository.
- **ArgoCD**: 13 Application resources manage all platform components with automated sync, self-heal, and pruning. Uses an App-of-Apps pattern — `platform-manifests` manages all other 12 Application manifests via kustomize.
- **KSOPS**: Kustomize exec plugin for decrypting SOPS+age encrypted secrets at sync time — secrets are encrypted at rest in git.
- **Helmfile**: Defines Helm release values (used by CI for linting/validation; ArgoCD Applications mirror the values for deployment).
- **ArgoCD UI**: Exposed at `argocd.cereghino.me` with Dex SSO (GitHub OIDC).

### 4. Security & Access
Zero-trust and identity verification are built-in from the start.
- **Dex & OAuth2-Proxy**: Implements Identity-Aware Proxying (IAP) via GitHub OIDC. Services like Hubble UI and ArgoCD are behind this authentication layer.
- **SOPS + age**: All Kubernetes secrets are encrypted in git and only decrypted in-cluster by KSOPS.
- **Coraza WAF**: A Web Application Firewall (Caddy + Coraza with OWASP CRS) deployed to inspect and filter traffic to Vaultwarden and Grafana. **Deprecated** (see ADR-022) — the operational overhead of self-managing WAF rules outweighs the benefits; Cloudflare Proxy managed firewall is the recommended approach for new deployments.
- **Kubeconfig Auth**: Kubectl access is secured via OIDC, dropping the need for static, long-lived cluster admin tokens.

### 5. Observability & Backups
- **Monitoring**: `kube-prometheus-stack` handles metrics collection and dashboards.
- **Network Visibility**: Cilium Hubble provides rich, graphical network flow observability.
- **Disaster Recovery**:
  - **Etcd**: Automated hourly backups to Hetzner S3, encrypted with `age`.
  - **Workloads**: Velero handles Kubernetes manifest and persistent volume backups.

### 6. Platform Services
- **Vaultwarden**: Self-hosted password manager backed by CloudNativePG PostgreSQL (3 replicas).
- **Backstage**: Developer portal for service catalog and documentation.
- **Crossplane**: Infrastructure control plane with providers for Kubernetes, Helm, AWS, and Hetzner Cloud.

## Repository Structure

- `infrastructure/`: OpenTofu modules and configurations to spin up the Hetzner servers, networking, and bootstrap the Talos cluster.
- `infrastructure/packer/`: Packer image definitions for Talos Linux snapshots (amd64/arm64).
- `platform/`: Helmfile definitions, ArgoCD Application manifests, kustomize overlays, and raw Kubernetes manifests for all platform services.
- `platform/argocd-apps/`: ArgoCD Application resources (one per platform component, 13 total).
- `platform/waf-chart/`: Custom Helm chart for the Coraza WAF (deprecated).
- `scripts/`: Utility scripts (upstream module sync, SOPS environment loader).
- `secrets/`: SOPS-encrypted local development environment secrets.
- `.github/workflows/`: CI (lint, plan, validate) and Infrastructure CD (auto-apply on master).
- `docs/adrs/`: Architecture Decision Records (ADRs) documenting key design decisions (30 ADRs covering infrastructure, networking, security, platform, and observability choices).

## Getting Started

Deploying this cluster is a two-step process:

1. **Infrastructure**:
   ```bash
   source scripts/env.sh                       # Load SOPS-encrypted secrets
   cd infrastructure
   tofu init
   tofu apply
   ```
   *This provisions the VMs, networks, and bootstraps Talos Kubernetes. The `sops-age-key` Secret is created in the `argocd` namespace via a Talos inline manifest.*

2. **Platform Layer** (bootstrap ArgoCD, then it takes over):
   ```bash
   cd platform
   helmfile apply --selector name=argocd            # Install ArgoCD
   kubectl apply -f argocd-apps/platform-manifests.yaml  # Bootstrap the root App-of-Apps
   ```
   *`platform-manifests` then reconciles all other ArgoCD Applications and platform services from git automatically. Subsequent changes are deployed by pushing to `master`.*

## Exposed Services

| Service | Domain | Protection |
|---------|--------|------------|
| ArgoCD | argocd.cereghino.me | Dex SSO (GitHub OIDC) |
| Backstage | backstage.cereghino.me | Direct |
| Dex | dex.cereghino.me | Direct (OIDC issuer) |
| Hubble UI | hubble.cereghino.me | OAuth2-Proxy (GitHub OIDC) |
| Vaultwarden | vault.cereghino.me | Coraza WAF (deprecated) |
| Grafana | grafana.cereghino.me | Coraza WAF (deprecated) |
