locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "acm"
  })

  certificate_domains = distinct(concat([var.domain_name], var.subject_alternative_names))

  # ACM can return the same DNS validation record for an apex domain and its
  # wildcard SAN. Use input-derived keys so Terraform can plan the records before
  # ACM returns validation_options, while avoiding duplicate Cloudflare records.
  validation_domain_keys = toset([
    for domain in local.certificate_domains : trimprefix(domain, "*.")
  ])
}

data "cloudflare_zones" "this" {
  name   = var.cloudflare_zone_name
  status = "active"
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(local.common_tags, {
    Name = var.domain_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  cloudflare_zone_id = one(data.cloudflare_zones.this.result[*].id)
  validation_options_by_domain = {
    for option in aws_acm_certificate.this.domain_validation_options :
    trimprefix(option.domain_name, "*.") => {
      name    = trimsuffix(option.resource_record_name, ".")
      type    = option.resource_record_type
      content = trimsuffix(option.resource_record_value, ".")
    }...
  }
  validation_options_map = {
    for domain, options in local.validation_options_by_domain : domain => options[0]
  }
}

resource "cloudflare_dns_record" "validation" {
  for_each = local.validation_domain_keys

  zone_id = local.cloudflare_zone_id
  name    = local.validation_options_map[each.key].name
  type    = local.validation_options_map[each.key].type
  content = local.validation_options_map[each.key].content
  ttl     = 60
  proxied = false
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.validation : record.name]
}
