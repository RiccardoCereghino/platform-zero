# SRE Homelab Cluster

Welcome to my Kubernetes homelab. This repository contains the declarative infrastructure and platform configuration for a highly resilient, secure, and observable Kubernetes cluster running on Hetzner Cloud.

Built with Site Reliability Engineering (SRE) principles in mind, this project goes beyond a simple deployment by incorporating immutable infrastructure, advanced layer 7 networking, automated encrypted backups, GitOps delivery, and identity-aware proxying.

## Architecture & Core Components

### 1. Infrastructure (OpenTofu + Talos Linux)
The underlying infrastructure is provisioned on Hetzner Cloud using OpenTofu. We use **Talos Linux** as the operating system — an immutable, specialized OS designed explicitly for Kubernetes.
- **Node Topology**: 1 Control Plane, 2 Worker nodes (configured in `infrastructure/terraform.tfvars`).
- **Storage**: Hetzner CSI with LUKS-encrypted volumes (`vault-storage` StorageClass) for stateful workloads.
- **State Management**: OpenTofu state is securely stored in a remote S3 backend.

### 2. Networking (Cilium + Gateway API)
We bypass legacy `kube-proxy` and standard Ingress controllers in favor of a modern networking stack.
- **Cilium CNI**: Provides high-performance eBPF-based overlay networking.
- **Gateway API**: Layer 7 traffic routing and TLS termination via HTTPRoutes.
- **Pod-to-Pod Encryption**: Transparent WireGuard encryption for all intra-cluster traffic.
- **ExternalDNS & Cert-Manager**: Automated DNS record creation (Cloudflare) and Let's Encrypt TLS certificate provisioning.

### 3. GitOps & Delivery (ArgoCD + KSOPS)
Platform delivery uses a pull-based GitOps model. ArgoCD runs in-cluster and continuously reconciles the desired state from this repository.
- **ArgoCD**: 8 Application resources manage all platform components with automated sync, self-heal, and pruning.
- **KSOPS**: Kustomize exec plugin for decrypting SOPS+age encrypted secrets at sync time — secrets are encrypted at rest in git.
- **Helmfile**: Defines Helm release values (used by CI for linting/validation; ArgoCD Applications mirror the values for deployment).
- **ArgoCD UI**: Exposed at `argocd.cereghino.me` with Dex SSO (GitHub OIDC).

### 4. Security & Access
Zero-trust and identity verification are built-in from the start.
- **Dex & OAuth2-Proxy**: Implements Identity-Aware Proxying (IAP) via GitHub OIDC. Services like Hubble UI and ArgoCD are behind this authentication layer.
- **SOPS + age**: All Kubernetes secrets are encrypted in git and only decrypted in-cluster by KSOPS.
- **Coraza WAF**: A Web Application Firewall (Caddy + Coraza) deployed to inspect and filter traffic to sensitive endpoints like Vaultwarden and Grafana.
- **Kubeconfig Auth**: Kubectl access is secured via OIDC, dropping the need for static, long-lived cluster admin tokens.

### 5. Observability & Backups
- **Monitoring**: `kube-prometheus-stack` handles metrics collection and dashboards.
- **Network Visibility**: Cilium Hubble provides rich, graphical network flow observability.
- **Disaster Recovery**:
  - **Etcd**: Automated backups to Hetzner S3, strongly encrypted with `age`.
  - **Workloads**: Velero handles Kubernetes manifest and persistent volume backups.

## Repository Structure

- `infrastructure/`: OpenTofu modules and configurations to spin up the Hetzner servers, networking, and bootstrap the Talos cluster.
- `platform/`: Helmfile definitions, ArgoCD Application manifests, kustomize overlays, and raw Kubernetes manifests for all platform services.
- `platform/argocd-apps/`: ArgoCD Application resources (one per platform component).
- `platform/waf-chart/`: Custom Helm chart for the Coraza WAF.
- `apps/`: (To be populated) End-user applications and workloads.
- `scripts/`: Utility scripts, including upstream synchronization tools.

## Getting Started

Deploying this cluster is a two-step process:

1. **Infrastructure**:
   ```bash
   cd infrastructure
   tofu init
   tofu apply
   ```
   *This provisions the VMs, networks, and bootstraps Talos Kubernetes. The `sops-age-key` Secret is created in the `argocd` namespace via a Talos inline manifest.*

2. **Platform Layer** (bootstrap ArgoCD, then it takes over):
   ```bash
   cd platform
   helmfile apply --selector name=argocd    # Install ArgoCD
   kubectl apply -f argocd-apps/            # Deploy all ArgoCD Applications
   ```
   *ArgoCD then reconciles all platform services from git automatically. Subsequent changes are deployed by pushing to `master`.*

## Exposed Services

| Service | Domain | Protection |
|---------|--------|------------|
| ArgoCD | argocd.cereghino.me | Dex SSO (GitHub OIDC) |
| Dex | dex.cereghino.me | Direct (OIDC issuer) |
| Hubble UI | hubble.cereghino.me | OAuth2-Proxy (GitHub OIDC) |
| Vaultwarden | vault.cereghino.me | Coraza WAF |
| Grafana | grafana.cereghino.me | Coraza WAF |
