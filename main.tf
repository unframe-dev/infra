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

# The apex record is required for the route-based LP and Editor Workers. The
# API Worker uses a Custom Domain, which creates its own DNS records.
resource "cloudflare_dns_record" "apex_worker" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "AAAA"
  content = var.worker_origin_ipv6
  proxied = true
  ttl     = 1
}

# The LP owns the broad route. More specific Editor routes take precedence.
resource "cloudflare_workers_route" "lp" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/*"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "editor_root" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/editor"
  script  = var.editor_worker_name
}

resource "cloudflare_workers_route" "editor_subpath" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/editor/*"
  script  = var.editor_worker_name
}

# Unlike a route, a Custom Domain owns every path on its hostname and
# provisions the hostname's DNS/TLS records through Cloudflare.
resource "cloudflare_workers_custom_domain" "control_plane" {
  account_id = var.cloudflare_account_id
  hostname   = "api.${var.zone_name}"
  service    = var.control_plane_worker_name
  zone_id    = data.cloudflare_zone.main.id
}

resource "cloudflare_workers_custom_domain" "mitou_slide" {
  account_id = var.cloudflare_account_id
  hostname   = "mitoujr.${var.zone_name}"
  service    = var.mitou_slide_worker_name
  zone_id    = data.cloudflare_zone.main.id
}
