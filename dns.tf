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

# Caddy at the origin terminates TLS for native gRPC and browser WebSocket.
resource "cloudflare_dns_record" "realtime" {
  count = var.realtime_origin_ipv4 == null ? 0 : 1

  zone_id = data.cloudflare_zone.main.id
  name    = "realtime.${var.zone_name}"
  type    = "A"
  content = var.realtime_origin_ipv4
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "realtime_ipv6" {
  count = var.realtime_origin_ipv6 == null ? 0 : 1

  zone_id = data.cloudflare_zone.main.id
  name    = "realtime.${var.zone_name}"
  type    = "AAAA"
  content = var.realtime_origin_ipv6
  proxied = false
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
