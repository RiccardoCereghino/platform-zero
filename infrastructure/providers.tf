provider "hcloud" {
  token         = var.hcloud_token
  poll_interval = "2s"
}

provider "aws" {
  region                      = var.talos_backup_s3_region
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
  endpoints {
    s3 = "https://${var.talos_backup_s3_region}.your-objectstorage.com"
  }
}

provider "helm" {
  repository_config_path = "${path.module}/.helm/repositories.yaml"

  kubernetes = {
    config_path = "${path.module}/.helm/kubeconfig"
  }
}
