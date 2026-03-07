# ──────────────────────────────────────────────────────────────
# Cluster Configuration — Minimal Learning Setup
# ──────────────────────────────────────────────────────────────
# hcloud_token is provided via TF_VAR_hcloud_token env variable.
# See ../.envrc for the 1Password integration.

cluster_name = "k8s"

# Pin to match installed talosctl version (talosctl version --client --short)
talos_version = "v1.11.5"

# Export kubeconfig and talosconfig to files for CLI access
cluster_kubeconfig_path  = "kubeconfig"
cluster_talosconfig_path = "talosconfig"

# ──────────────────────────────────────────────────────────────
# Node Pools — 1 CP + 2 Workers (CPX22: 2 vCPU, 4GB RAM, 40GB)
# ──────────────────────────────────────────────────────────────
# NOTE: 1 CP = no HA / no etcd quorum. Acceptable for learning.
# Scale to 3 CP when moving to production workloads.

control_plane_nodepools = [
  {
    name     = "control"
    type     = "cpx22"
    location = "nbg1"
    count    = 1
  }
]

worker_nodepools = [
  {
    name     = "worker"
    type     = "cpx22"
    location = "nbg1"
    count    = 2
  }
]

# ──────────────────────────────────────────────────────────────
# L7 Networking — Cilium Gateway API
# ──────────────────────────────────────────────────────────────
cilium_gateway_api_enabled  = true
cilium_hubble_enabled       = true
cilium_hubble_relay_enabled = true
cilium_hubble_ui_enabled    = true

# ──────────────────────────────────────────────────────────────
# Observability — Metrics Server + Prometheus Operator CRDs
# ──────────────────────────────────────────────────────────────
metrics_server_enabled           = true
prometheus_operator_crds_enabled = true

# ──────────────────────────────────────────────────────────────
# Encryption — Transparent WireGuard pod-to-pod encryption
# ──────────────────────────────────────────────────────────────
cilium_encryption_enabled     = true
cilium_encryption_type        = "wireguard"
cilium_egress_gateway_enabled = true

# ──────────────────────────────────────────────────────────────
# Bug Fix — Disable proxy protocol to avoid Cilium IPv6 issue
# ──────────────────────────────────────────────────────────────
cilium_gateway_api_proxy_protocol_enabled = false

# ──────────────────────────────────────────────────────────────
# Etcd Backup Configuration
# ──────────────────────────────────────────────────────────────
talos_backup_schedule              = "0 * * * *"
talos_backup_s3_bucket             = "cereghino-infra-backups"
talos_backup_s3_endpoint           = "https://nbg1.your-objectstorage.com"
talos_backup_s3_region             = "nbg1"
talos_backup_age_x25519_public_key = "age1xpjupmvsge5h30fpsf0ykz4h3z9sp4942veq6qfshcw893kwy3lsv6r5nd"

# ──────────────────────────────────────────────────────────────
# Storage Configuration
# ──────────────────────────────────────────────────────────────
hcloud_csi_storage_classes = [
  {
    name          = "vault-storage"
    encrypted     = true
    reclaimPolicy = "Retain"
  }
]

# ──────────────────────────────────────────────────────────────
# OIDC Configuration
# ──────────────────────────────────────────────────────────────
oidc_enabled        = true
oidc_issuer_url     = "https://dex.cereghino.me"
oidc_client_id      = "kubernetes-cli"
oidc_username_claim = "email"
oidc_groups_claim   = "groups"
