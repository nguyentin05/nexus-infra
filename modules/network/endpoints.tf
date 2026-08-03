data "aws_region" "current" {}

locals {
  ecr_endpoint_services = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  #checkov:skip=CKV2_AWS_5:The security group is attached to the ECR interface endpoints below.
  name_prefix = "${var.environment}-vpc-endpoint-"
  description = "PrivateLink endpoints for EKS workloads"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "vpc-endpoint-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "vpc_endpoints_https_from_nodes" {
  description              = "HTTPS from EKS worker nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints.id
  source_security_group_id = aws_security_group.node_sg.id
}

resource "aws_vpc_endpoint" "ecr" {
  for_each = local.ecr_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.common_tags, {
    Name = "vpc-endpoint-${replace(each.value, ".", "-")}"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = values(aws_route_table.private)[*].id

  tags = merge(local.common_tags, {
    Name = "vpc-endpoint-s3"
  })
}
