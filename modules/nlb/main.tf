locals {
  common_tags = merge(var.tags, {
    Module = "nlb"
  })
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "this" {
  name_prefix = "${var.environment}-public-nlb-"
  description = "Security group for the public API NLB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    description     = "Envoy Gateway targets"
    from_port       = var.target_port
    to_port         = var.target_port
    protocol        = "tcp"
    security_groups = [var.target_security_group_id]
  }

  tags = merge(local.common_tags, {
    Name = "public-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "targets_from_nlb" {
  type                     = "ingress"
  description              = "Allow public NLB to reach Envoy Gateway targets"
  security_group_id        = var.target_security_group_id
  source_security_group_id = aws_security_group.this.id
  from_port                = var.target_port
  to_port                  = var.target_port
  protocol                 = "tcp"
}

#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs require a dedicated S3 logging boundary and are deferred for the ephemeral environment.
  #checkov:skip=CKV_AWS_150:Deletion protection would prevent the documented destroy/recreate development workflow.
  name               = var.name
  load_balancer_type = "network"
  internal           = false
  security_groups    = [aws_security_group.this.id]
  subnets            = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "public-nlb"
  })
}

resource "aws_lb_target_group" "envoy" {
  name        = var.target_group_name
  port        = var.target_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = "envoy-target-group"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy.arn
  }
}
