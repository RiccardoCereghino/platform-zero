# SRE Homelab Cluster

Welcome to my Kubernetes homelab. This repository contains the declarative infrastructure and platform configuration for a highly resilient, secure, and observable Kubernetes cluster running on Hetzner Cloud.

Built with Site Reliability Engineering (SRE) principles in mind, this project goes beyond a simple deployment by incorporating immutable infrastructure, advanced layer 7 networking, automated encrypted backups, and identity-aware proxying.

## 🏗️ Architecture & Core Components

### 1. Infrastructure (OpenTofu + Talos Linux)
The underlying infrastructure is provisioned on Hetzner Cloud using OpenTofu. We use **Talos Linux** as the operating system—an immutable, specialized OS designed explicitly for Kubernetes.
- **Node Topology**: 1 Control Plane, 2 Worker nodes (configured in `infrastructure/terraform.tfvars`).
- **Storage**: Hetzner CSI with LUKS-encrypted volumes (`vault-storage` StorageClass) for stateful workloads.
- **State Management**: OpenTofu state is securely stored in a remote S3 backend.

### 2. Networking (Cilium + Gateway API)
We bypass legacy `kube-proxy` and standard Ingress controllers in favor of a modern networking stack.
- **Cilium CNI**: Provides high-performance overlay networking.
- **Gateway API**: Layer 7 traffic routing and TLS termination.
- **Pod-to-Pod Encryption**: Transparent WireGuard encryption for all intra-cluster traffic.
- **ExternalDNS & Cert-Manager**: Automated DNS record creation (Cloudflare) and Let's Encrypt TLS certificate provisioning.

### 3. Security & Access
Zero-trust and identity verification are built-in from the start.
- **Dex & OAuth2-Proxy**: Implements Identity-Aware Proxying (IAP) via GitHub OIDC. Services like Hubble UI are hidden behind this authentication layer.
- **Coraza WAF**: A Web Application Firewall (Caddy + Coraza) deployed to inspect and filter traffic to sensitive endpoints like Vaultwarden and Grafana.
- **Kubeconfig Auth**: Kubectl access is secured via OIDC, dropping the need for static, long-lived cluster admin tokens.

### 4. Observability & Backups
- **Monitoring**: `kube-prometheus-stack` handles metrics collection and dashboards.
- **Network Visibility**: Cilium Hubble provides rich, graphical network flow observability.
- **Disaster Recovery**:
  - **Etcd**: Automated backups to Hetzner S3, strongly encrypted with `age`.
  - **Workloads**: Velero handles Kubernetes manifest and persistent volume backups.

## 📁 Repository Structure

- `infrastructure/`: OpenTofu modules and configurations to spin up the Hetzner servers, networking, and bootstrap the Talos cluster.
- `platform/`: Helmfile and raw Kubernetes manifests for deploying the core platform services (WAF, DNS, Cert Manager, Dex, Observability).
- `apps/`: (To be populated) End-user applications and workloads.
- `scripts/`: Utility scripts, including upstream synchronization tools.

## 🚀 Getting Started

Deploying this cluster is a two-step process:

1. **Infrastructure**:
   ```bash
   cd infrastructure
   tofu init
   tofu apply
   ```
   *This provisions the VMs, networks, and bootstraps Talos Kubernetes.*

2. **Platform Layer**:
   ```bash
   cd platform
   helmfile apply
   ```
   *This deploys all base services, operators, and routing rules.*
