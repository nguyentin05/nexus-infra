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
  validation_record  = tolist(aws_acm_certificate.this.domain_validation_options)[0]
}

resource "cloudflare_dns_record" "validation" {
  zone_id = local.cloudflare_zone_id
  name    = trimsuffix(local.validation_record.resource_record_name, ".")
  type    = local.validation_record.resource_record_type
  content = trimsuffix(local.validation_record.resource_record_value, ".")
  ttl     = 60
  proxied = false
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [cloudflare_dns_record.validation.name]
}
