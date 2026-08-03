locals {
  validation_domain_keys = toset([
    for domain in concat([var.domain_name], var.subject_alternative_names) :
    trimprefix(domain, "*.")
  ])

  common_tags = merge(var.tags, {
    Module = "acm"
  })
}

data "cloudflare_zone" "this" {
  filter = {
    name = var.cloudflare_zone_name
  }
}

resource "aws_acm_certificate" "this" {
  #checkov:skip=CKV2_AWS_71:The wildcard SAN is required for environment-specific subdomains under the owned zone.
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(local.common_tags, {
    Name = "acm-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

locals {
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

  zone_id = data.cloudflare_zone.this.id
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
