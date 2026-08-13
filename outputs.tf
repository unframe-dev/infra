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
    lp             = cloudflare_workers_route.lp.pattern
    editor_root    = cloudflare_workers_route.editor_root.pattern
    editor_subpath = cloudflare_workers_route.editor_subpath.pattern
  }
}
