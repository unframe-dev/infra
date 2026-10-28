terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.22.0"
    }
  }
}

# Authentication is read from CLOUDFLARE_API_TOKEN. Keeping the token out of
# Terraform configuration prevents it from being written to the state file.
provider "cloudflare" {}

data "cloudflare_zone" "main" {
  filter = {
    account = {
      id = var.cloudflare_account_id
    }
    name = var.zone_name
  }
}
