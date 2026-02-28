TODO — Unresolved Architectural Decisions
This file tracks architectural gaps in the Kubernetes platform.  
Each section is a decision to be made — not a bug to fix.

🟢 Phase 1: Infrastructure Survival (Current Focus)
1. Secrets Management

Question: How do we stop creating manual secrets?

Current State: Cloudflare token is a manual secret.

Goal: Deploy External Secrets Operator (ESO) linked to 1Password.

Action: Install ESO and configure a SecretStore to pull credentials directly from 1Password via the Connect API.

2. Disaster Recovery

Question: If the single Control Plane node dies, is the cluster gone?

etcd Snapshots: Create a Hetzner Object Storage bucket. Update terraform.tfvars with the S3 credentials to push automated encrypted etcd snapshots.

Application Backup: Install Velero to back up manifests and PV data to S3.

Goal: Be able to run tofu destroy and tofu apply and have the cluster back in 15 minutes.

3. DNS Automation

Question: How do we stop manually creating A-records in Cloudflare?

Goal: Deploy ExternalDNS.

Action: Configure ExternalDNS to watch Gateway and HTTPRoute resources.

Result: Creating a route for app.cereghino.me automatically creates the Cloudflare DNS record.

🟡 Phase 2: Workload Capability
4. Stateful Data / Databases

Question: How should we run databases in the cluster?

Recommendation: Start with Hetzner Block Volumes (CSI) for the "80/20" simplicity.

Future-proofing: If IOPS become a bottleneck, evaluate pooling local NVMe with Longhorn.

Operator: Deploy CloudNativePG to manage Postgres life-cycles on top of the CSI.

5. Layer 7 Security (WAF)

Question: Now that we have HTTPS, how do we stop bot attacks?

Action: Evaluate Coraza WAF as an Envoy filter within the Cilium Gateway.

Alternative: Toggle the Cloudflare "Proxy" (Orange Cloud) on for basic edge protection.

🔵 Phase 3: Operations & Growth
6. Observability & Monitoring

Question: How do we see what's happening?

Metrics: Deploy the kube-prometheus-stack (Prometheus + Grafana).

Logging: Evaluate Loki for lightweight log aggregation.

Network: Enable Cilium Hubble to visualize pod-to-pod traffic.

7. GitOps / Continuous Delivery

Question: How do we move away from kubectl apply?

Goal: Implement ArgoCD or Flux.

Result: The cluster becomes a mirror of the GitHub repository.

8. Scaling & Multi-Environment

Scaling: Upgrade to 3 Control Plane nodes for HA and enable the Cluster Autoscaler when costs permit.

Environment: Use Namespaces and Kustomize to separate production from experimental workloads.

---

🔴 Priority 1: The Foundation (Do this now)

Disaster Recovery (The "Lifeboat"): * Create a Hetzner Object Storage bucket (S3 compatible).

Configure Talos etcd backups to this bucket so the cluster's brain is safe.

Persistent Storage Policy: * We will use Hetzner CSI (Block Storage) for Vaultwarden.

Action: Review the StorageClass to ensure reclaimPolicy: Retain is set, so deleting a helm release doesn't accidentally wipe your database.

🟡 Priority 2: The Vault Deployment

Vaultwarden Implementation: * Deploy Vaultwarden with a sidecar container (like backupto-s3) that streams the SQLite database to your Hetzner S3 bucket every hour.

Route vault.cereghino.me through your Cilium Gateway.

External Secrets Operator (ESO):

Now that the vault is inside the cluster, we'll configure ESO to pull from the local Vaultwarden API instead of 1Password.

🟢 Priority 3: Automation & Cleaning

DNS Automation (ExternalDNS): Stop manual A-record creation in Cloudflare.

Monitoring: Get Prometheus/Grafana up so you get an alert if Vaultwarden's disk is getting full.