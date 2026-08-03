data "cloudflare_zone" "this" {
  filter = {
    name = "tin-nexus.com"
  }
}

resource "cloudflare_dns_record" "api" {
  zone_id = data.cloudflare_zone.this.id
  name    = "api-prod.tin-nexus.com"
  type    = "CNAME"
  content = module.cloudfront.domain_name
  ttl     = 60
  proxied = false
}
