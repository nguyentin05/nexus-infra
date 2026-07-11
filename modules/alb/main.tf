locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "alb"
  })
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "this" {
  name_prefix = "${var.environment}-public-alb-"
  description = "Security group for the public API ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "targets_from_alb" {
  type                     = "ingress"
  description              = "Allow public ALB to reach Envoy Gateway targets"
  security_group_id        = var.target_security_group_id
  source_security_group_id = aws_security_group.this.id
  from_port                = var.target_port
  to_port                  = var.target_port
  protocol                 = "tcp"
}

resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.this.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

resource "aws_lb_target_group" "envoy" {
  name        = var.target_group_name
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = var.target_group_name
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy.arn
  }
}
