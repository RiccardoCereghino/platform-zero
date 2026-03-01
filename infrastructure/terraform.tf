terraform {
  required_version = ">=1.9.0"

  backend "s3" {
    bucket                      = "cereghino-tf-state"
    key                         = "k8s/terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
    use_path_style              = true
  }

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.0"
    }
  }
}
