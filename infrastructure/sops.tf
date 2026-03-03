locals {
  sops_age_key_manifest = var.sops_age_private_key != "" ? {
    name = "sops-age-key"
    contents = join("\n---\n", [
      yamlencode({
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = "argocd"
        }
      }),
      yamlencode({
        apiVersion = "v1"
        kind       = "Secret"
        type       = "Opaque"
        metadata = {
          name      = "sops-age-key"
          namespace = "argocd"
        }
        data = {
          "keys.txt" = base64encode(var.sops_age_private_key)
        }
      })
    ])
  } : null
}
