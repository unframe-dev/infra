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

# Resend authenticates noreply@un-fra.me with DKIM and a dedicated MAIL FROM
# subdomain. DMARC starts in monitoring mode until delivery is verified.
resource "cloudflare_dns_record" "resend_dkim" {
  zone_id = data.cloudflare_zone.main.id
  name    = "resend._domainkey"
  type    = "TXT"
  content = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDNCkGWoPIXb1O3eI5ro0WsW0ZRH44pclQoAXHhUBieGYonlpkzK3kU2GcR6azI9H0nqvezFkk3uFeWgOaAiMS9FVqCTIpBw5eXS/c9TF9/aNH+eaRsHavZejFHNBWnel9B4zywr526EMDdhMxo3LrAt68vMY4p5NK4T5z/wC5t9wIDAQAB"
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "resend_mail_from_mx" {
  zone_id  = data.cloudflare_zone.main.id
  name     = "send"
  type     = "MX"
  content  = "feedback-smtp.ap-northeast-1.amazonses.com"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "resend_mail_from_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = "send"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "resend_dmarc" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none;"
  proxied = false
  ttl     = 1
}

# LP is an allowlist on the apex hostname. The Editor fallback below owns
# every path that is not explicitly reserved for the LP.
resource "cloudflare_workers_route" "lp_root" {
  zone_id = data.cloudflare_zone.main.id
  pattern = var.zone_name
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_news" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/news"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_news_subpath" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/news/*"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_docs" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/docs"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_docs_subpath" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/docs/*"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_app_assets" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/_app/*"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_brand_assets" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/brand/*"
  script  = var.lp_worker_name
}

resource "cloudflare_workers_route" "lp_favicon_assets" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/favicon/*"
  script  = var.lp_worker_name
}

# The root-based Editor owns every path not reserved by the LP routes above.
resource "cloudflare_workers_route" "editor_fallback" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "${var.zone_name}/*"
  script  = var.editor_worker_name
}

# Preserve the existing route state during the topology migration. The old
# route IDs are updated in place instead of being recreated as duplicates.
moved {
  from = cloudflare_workers_route.lp
  to   = cloudflare_workers_route.editor_fallback
}

moved {
  from = cloudflare_workers_route.editor_root
  to   = cloudflare_workers_route.lp_root
}

moved {
  from = cloudflare_workers_route.editor_subpath
  to   = cloudflare_workers_route.lp_news
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
