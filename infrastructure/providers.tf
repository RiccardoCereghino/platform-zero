provider "hcloud" {
  token         = var.hcloud_token
  poll_interval = "2s"
}

provider "aws" {
  region                      = "nbg1"
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
  endpoints {
    s3 = "https://nbg1.your-objectstorage.com"
  }
}

provider "helm" {
  repository_config_path = "${path.module}/.helm/repositories.yaml"

  kubernetes = {
    config_path = "${path.module}/.helm/kubeconfig"
  }
}
