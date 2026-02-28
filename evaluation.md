# Homelab Kubernetes Project — Evaluation

> Snapshot taken **2026-02-28** after the ExternalDNS + TLS work.

---

## What You're Doing Right

### 1. Infrastructure-as-Code Foundation ✅
- The entire cluster (servers, networking, firewall, Talos config, Cilium CNI, cert-manager) is managed in Terraform with pinned provider versions.
- [terraform.tfvars](file:///Users/cerre/DevOps/infrastracture/terraform.tfvars) is clean, well-commented, and separates config from code.
- Sensitive outputs ([kubeconfig](file:///Users/cerre/DevOps/infrastracture/kubeconfig), [talosconfig](file:///Users/cerre/DevOps/infrastracture/talosconfig)) are marked `sensitive = true`.

### 2. Upstream Module Strategy ✅
- Forking `hcloud-k8s/terraform-hcloud-kubernetes` and owning the [.tf](file:///Users/cerre/DevOps/infrastracture/oidc.tf) files directly gives you full control.
- The [upstream-sync.sh](file:///Users/cerre/DevOps/scripts/upstream-sync.sh) script is a smart way to track upstream drift without losing local changes.

### 3. Networking Stack ✅
- Choosing **Cilium Gateway API** over a separate ingress controller is the modern approach — fewer moving parts, native L7 in the CNI.
- The Gateway manifest uses a **wildcard cert** (`*.cereghino.me`) so every new route gets TLS for free.
- ExternalDNS is configured with `policy: sync` and a unique `txtOwnerId`, which is best practice for preventing record conflicts.

### 4. Secret Injection via 1Password ✅
- Using `op read` in [.envrc](file:///Users/cerre/DevOps/.envrc) to inject `HCLOUD_TOKEN` is a solid zero-secret-on-disk pattern.
- The [.gitignore](file:///Users/cerre/DevOps/infrastracture/.gitignore) correctly excludes [kubeconfig](file:///Users/cerre/DevOps/infrastracture/kubeconfig), [talosconfig](file:///Users/cerre/DevOps/infrastracture/talosconfig), and `*.tfstate`.

### 5. Phased TODO Roadmap ✅
- The [TODO.md](file:///Users/cerre/DevOps/TODO.md) is well-structured with clear phases, questions, and actions. This is mature project management for a personal project.

---

## What Needs Attention

### 🔴 Critical: Terraform State is Local

**The biggest risk in the entire project.**

| Problem | Impact |
|---|---|
| [terraform.tfstate](file:///Users/cerre/DevOps/infrastracture/terraform.tfstate) (9.6 MB) sits on your local disk | Laptop dies → you lose the mapping between Terraform and Hetzner resources |
| No state locking | Not a problem solo, but a bad habit to carry forward |

**Recommendation:** Create a Hetzner Object Storage (S3) bucket and add a `backend "s3"` block to [terraform.tf](file:///Users/cerre/DevOps/infrastracture/terraform.tf). This is a 10-minute fix that eliminates the single biggest disaster recovery gap — even before etcd backups matter, because without state you can't even run `tofu plan`.

```hcl
# terraform.tf — add this block
terraform {
  backend "s3" {
    bucket     = "cereghino-tf-state"
    key        = "k8s/terraform.tfstate"
    region     = "eu-central-1"            # Hetzner S3 region
    endpoints  = { s3 = "https://nbg1.your-objectstorage.com" }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
  }
}
```

---

### 🟡 Git Hygiene: Single Mega-Commit

The entire project is one commit (`3d3abac`), with 4 more files staged but not committed. This makes it impossible to rollback individual changes or understand what changed when.

**Recommendation:**
1. Commit the staged changes **now** with a descriptive message.
2. Going forward, commit per logical unit of work (e.g., "feat: add ExternalDNS via helmfile", "feat: add TLS with wildcard cert").
3. Consider conventional commits (`feat:`, `fix:`, `chore:`) for a clean history.

---

### 🟡 Typo: `infrastracture/` → `infrastructure/`

The directory name has a typo (`infrastracture`). It's referenced in [upstream-sync.sh](file:///Users/cerre/DevOps/scripts/upstream-sync.sh) and [.gitignore](file:///Users/cerre/DevOps/infrastracture/.gitignore), so renaming requires updating those too. Easier to fix now while the project is young.

---

### 🟡 Test Manifests Live Inside `infrastracture/test/`

The Gateway, ClusterIssuer, and whoami deployment are test manifests inside the Terraform directory. This is fine for bootstrapping, but these are **Kubernetes resources**, not Terraform resources. They belong elsewhere in the project.

**Recommendation:** Move them to a structure that separates concerns:

```
apps/
  whoami/          # test workload
    deployment.yaml
    httproute.yaml
platform/
  helmfile.yaml    # already here ✅
  gateway.yaml     # the shared Gateway resource
  cluster-issuer.yaml
infrastracture/    # only Terraform files
```

This also prepares the layout for when you add GitOps (ArgoCD/Flux) — each directory becomes an ArgoCD Application.

---

### 🟡 The Gateway Is In a Test File

The `main-gateway` resource currently lives inside `l7-gateway-test.yaml` alongside the whoami Deployment. The Gateway is a **shared infrastructure resource** — not a per-app test. It should be its own manifest in `platform/`.

---

### 🟡 No HTTP → HTTPS Redirect

The Gateway has both an `http` (port 80) and `https` (port 443) listener, but there's no HTTPRoute that redirects port 80 traffic to 443. Anyone hitting `http://whoami.cereghino.me` gets a connection refused or an unencrypted response.

**Recommendation:** Add a redirect filter to the HTTPRoute:
```yaml
- matches:
    - path:
        type: PathPrefix
        value: /
  filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
```

---

### 🟢 Minor: `.envrc` Only Covers Hetzner Token

The Cloudflare API token for cert-manager/ExternalDNS is a manual `kubectl create secret`. As the project grows, consider pulling that into `.envrc` too (or ESO as your TODO suggests).

---

## Recommended Next Steps (Before Vaultwarden)

Based on your TODO and what I see in the repo, here's the order I'd tackle things:

| # | Action | Why |
|---|--------|-----|
| 1 | **Remote Terraform state** | Protects the one thing you can't recreate |
| 2 | **Commit & clean up Git history** | Low effort, high future value |
| 3 | **Reorganize manifests** (`apps/`, `platform/`) | Sets the stage for GitOps and Vaultwarden |
| 4 | **Add HTTP→HTTPS redirect** | Security hygiene before exposing real services |
| 5 | **Deploy Vaultwarden** | Your stated goal — now the foundation is solid |
| 6 | **etcd backups to S3** | Second disaster recovery layer |

---

## Summary Scorecard

| Area | Grade | Notes |
|------|-------|-------|
| IaC / Terraform | **A** | Pinned providers, clean vars, sensitive outputs |
| Networking (Cilium + Gateway API) | **A** | Modern, minimal stack |
| TLS / Cert Management | **A-** | Wildcard cert works; missing HTTP redirect |
| Secret Management | **B+** | 1Password for HCloud is great; CF token still manual |
| Disaster Recovery | **C** | Local tfstate is the single biggest risk |
| Project Structure | **B-** | Good dirs but manifests are misplaced |
| Git Practices | **C** | Single commit, no branching, staged changes sitting |
| Documentation (TODO) | **A** | Thoughtful, phased, realistic roadmap |

**Overall: You have a strong technical foundation.** The infra choices (Talos, Cilium, Gateway API, Hetzner CSI) are modern and well-integrated. The main gaps are operational hygiene (state, Git, directory layout) rather than architectural.
