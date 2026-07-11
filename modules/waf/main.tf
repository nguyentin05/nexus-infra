resource "aws_wafv2_web_acl" "this" {
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

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enabled && var.associate_alb && var.alb_arn != null && var.alb_arn != "" ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
