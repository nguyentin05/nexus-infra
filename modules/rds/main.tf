locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "rds"
  })
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.identifier}-subnet-group"
  description = "${var.identifier} private DB subnet group"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "PostgreSQL access for ${var.identifier}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS workload nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.identifier}-${var.parameter_group_family}"
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

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-parameters"
  })
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${var.identifier}/postgresql"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-postgresql"
  })
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.master_username

  manage_master_user_password = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  parameter_group_name            = aws_db_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  enabled_cloudwatch_logs_exports = ["postgresql"]
  publicly_accessible             = false
  multi_az                        = var.multi_az

  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = var.identifier
  })

  depends_on = [aws_cloudwatch_log_group.postgresql]
}
