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
# L7 Networking — Cilium Gateway API + Cert Manager
# ──────────────────────────────────────────────────────────────
cilium_gateway_api_enabled = true
cert_manager_enabled       = true
