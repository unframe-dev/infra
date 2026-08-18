output "zone_id" {
  description = "Cloudflare zone ID used by the managed routes and DNS record."
  value       = data.cloudflare_zone.main.id
}

output "control_plane_hostname" {
  description = "Control Plane Custom Domain hostname."
  value       = cloudflare_workers_custom_domain.control_plane.hostname
}

output "mitou_slide_hostname" {
  description = "Mitou Slide Custom Domain hostname."
  value       = cloudflare_workers_custom_domain.mitou_slide.hostname
}

output "managed_routes" {
  description = "Worker routes managed by Terraform."
  value = {
    lp_root           = cloudflare_workers_route.lp_root.pattern
    lp_news           = cloudflare_workers_route.lp_news.pattern
    lp_news_subpath   = cloudflare_workers_route.lp_news_subpath.pattern
    lp_docs           = cloudflare_workers_route.lp_docs.pattern
    lp_docs_subpath   = cloudflare_workers_route.lp_docs_subpath.pattern
    lp_app_assets     = cloudflare_workers_route.lp_app_assets.pattern
    lp_brand_assets   = cloudflare_workers_route.lp_brand_assets.pattern
    lp_favicon_assets = cloudflare_workers_route.lp_favicon_assets.pattern
    editor_fallback   = cloudflare_workers_route.editor_fallback.pattern
  }
}
