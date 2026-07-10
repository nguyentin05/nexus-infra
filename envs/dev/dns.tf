resource "cloudflare_dns_record" "api" {
  zone_id = module.acm.cloudflare_zone_id
  name    = "api.tin-nexus.com"
  type    = "CNAME"
  content = module.cloudfront.domain_name
  ttl     = 60
  proxied = false
}
