locals {
  origin_id = "${var.name}-alb"
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "cloudfront"
  })
}

#trivy:ignore:AVD-AWS-0011
resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_68:The regional WAF is attached to the ALB origin to keep one inspection layer.
  #checkov:skip=CKV_AWS_86:CloudFront access logging requires an S3 logging boundary and is deferred.
  #checkov:skip=CKV_AWS_374:The public API is intentionally available globally.
  #checkov:skip=CKV_AWS_305:This is an API distribution and has no root document.
  #checkov:skip=CKV_AWS_310:The current platform is single-region and has no valid failover origin.
  #checkov:skip=CKV2_AWS_47:The ALB WAF uses AWS managed Common and KnownBadInputs rule groups.
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  aliases         = var.aliases
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.origin_domain_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    min_ttl                    = 0
    default_ttl                = 0
    max_ttl                    = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}
