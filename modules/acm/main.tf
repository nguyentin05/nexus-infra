locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "acm"
  })
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
  validation_options = distinct([
    for option in aws_acm_certificate.this.domain_validation_options : {
      name    = trimsuffix(option.resource_record_name, ".")
      type    = option.resource_record_type
      content = trimsuffix(option.resource_record_value, ".")
    }
  ])
}

resource "cloudflare_dns_record" "validation" {
  for_each = {
    for option in local.validation_options : option.name => option
  }

  zone_id = local.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = 60
  proxied = false
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.validation : record.name]
}
