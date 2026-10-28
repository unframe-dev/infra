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
