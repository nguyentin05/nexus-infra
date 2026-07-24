resource "aws_cloudwatch_log_group" "this" {
  count = var.enabled ? 1 : 0

  #checkov:skip=CKV_AWS_158:CloudWatch encrypts logs at rest by default; a dedicated WAF logging key is deferred.
  #checkov:skip=CKV_AWS_338:Thirty days is sufficient for the current development and capstone audit window.
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "waf"
  })
}

resource "aws_wafv2_web_acl" "this" {
  #checkov:skip=CKV2_AWS_31:Logging is configured by aws_wafv2_web_acl_logging_configuration.this below.
  count = var.enabled ? 1 : 0

  name        = var.name
  description = "${var.environment} public ALB WAF"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}AmazonIpReputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        dynamic "rule_action_override" {
          for_each = var.override_size_restrictions_body_to_count ? [1] : []

          content {
            name = "SizeRestrictions_BODY"

            action_to_use {
              count {}
            }
          }
        }

        dynamic "rule_action_override" {
          for_each = var.override_cross_site_scripting_body_to_count ? [1] : []

          content {
            name = "CrossSiteScripting_BODY"

            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "waf"
  })

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}PublicAlbWaf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enabled ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.this[0].arn]
}

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enabled && var.associate_alb ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
