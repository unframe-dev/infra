variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the Workers."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hexadecimal ID."
  }
}

variable "zone_name" {
  description = "Cloudflare zone that hosts the Unframe applications."
  type        = string
  default     = "un-fra.me"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$", var.zone_name))
    error_message = "zone_name must be a DNS name without a trailing dot."
  }
}

variable "lp_worker_name" {
  description = "Existing Worker service name for the landing page."
  type        = string
  default     = "unframe-lp"
}

variable "editor_worker_name" {
  description = "Existing Worker service name for the Web Editor."
  type        = string
  default     = "unframe-web-editor"
}

variable "control_plane_worker_name" {
  description = "Existing Worker service name for the Control Plane."
  type        = string
  default     = "unframe-control-plane"
}

variable "mitou_slide_worker_name" {
  description = "Existing Worker service name for the Mitou Slide site."
  type        = string
  default     = "mitou-slide"
}

variable "worker_origin_ipv6" {
  description = "Cloudflare reserved IPv6 origin used by route-based Workers."
  type        = string
  default     = "100::"

  validation {
    condition     = can(cidrhost("${var.worker_origin_ipv6}/128", 0))
    error_message = "worker_origin_ipv6 must be a valid IPv6 address."
  }
}

variable "realtime_origin_ipv4" {
  description = "Public IPv4 address of the Realtime Caddy origin. Null disables its A record."
  type        = string
  default     = null

  validation {
    condition     = var.realtime_origin_ipv4 == null || can(cidrnetmask("${var.realtime_origin_ipv4}/32"))
    error_message = "realtime_origin_ipv4 must be null or a valid IPv4 address without a CIDR prefix."
  }
}

variable "realtime_origin_ipv6" {
  description = "Public IPv6 address of the Realtime Caddy origin. Null disables its AAAA record."
  type        = string
  default     = null

  validation {
    condition = var.realtime_origin_ipv6 == null || (
      can(regex(":", var.realtime_origin_ipv6)) && can(cidrhost("${var.realtime_origin_ipv6}/128", 0))
    )
    error_message = "realtime_origin_ipv6 must be null or a valid IPv6 address without a CIDR prefix."
  }
}
