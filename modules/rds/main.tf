locals {
  common_tags = merge(var.tags, {
    Module = "rds"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "rds-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "rds-sg"
  description = "PostgreSQL access for rds"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS workload nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  tags = merge(local.common_tags, {
    Name = "rds-sg"
  })
}

resource "aws_db_parameter_group" "this" {
  name   = "rds-${var.parameter_group_family}"
  family = var.parameter_group_family

  parameter {
    name         = "log_min_duration_statement"
    value        = "500"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_lock_waits"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  tags = merge(local.common_tags, {
    Name = "rds-parameters"
  })
}

resource "aws_cloudwatch_log_group" "postgresql" {
  #checkov:skip=CKV_AWS_158:CloudWatch encrypts logs at rest by default; a dedicated customer-managed logging key is deferred.
  #checkov:skip=CKV_AWS_338:Retention is environment-specific and intentionally short for ephemeral development clusters.
  name              = "/aws/rds/instance/${var.identifier}/postgresql"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "rds-postgresql"
  })
}

resource "aws_iam_role" "monitoring" {
  name = "${var.identifier}-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Multi-AZ is controlled per environment and intentionally disabled in ephemeral development.
  #checkov:skip=CKV_AWS_293:Deletion protection is controlled per environment and intentionally disabled in ephemeral development.
  identifier                          = var.identifier
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.allocated_storage * 2
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = var.database_name
  username                            = var.master_username
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  db_subnet_group_name                = aws_db_subnet_group.this.name
  parameter_group_name                = aws_db_parameter_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  publicly_accessible                 = false
  multi_az                            = var.multi_az
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = var.performance_insights_kms_key_id
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.monitoring.arn
  backup_retention_period             = var.backup_retention_period
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  auto_minor_version_upgrade          = true
  apply_immediately                   = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = var.identifier
  })

  depends_on = [aws_cloudwatch_log_group.postgresql]
}
