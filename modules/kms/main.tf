resource "aws_kms_key" "this" {
  description             = "${var.environment}-${var.key_alias} KMS key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "kms"
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.environment}-${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}