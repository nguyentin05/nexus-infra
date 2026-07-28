resource "aws_kms_key" "this" {
  #checkov:skip=CKV2_AWS_64:AWS supplies the default account key policy when policy is omitted.
  description             = "${var.key_alias} KMS key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Module = "kms"
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.environment}-${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}