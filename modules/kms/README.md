# KMS Module

Tạo 1 KMS key generic, dùng cho bất kỳ mục đích encryption nào (Vault auto-unseal, S3, EBS...). Key rotation bật mặc định.

## Sử dụng

\`\`\`hcl
module "kms_vault" {
  source = "../../modules/kms"

  environment = "dev"
  key_alias   = "vault-unseal"

  tags = { Project = "capstone" }
}
\`\`\`

Gọi module 2 lần (alias khác nhau) nếu cần nhiều key cho nhiều mục đích trong cùng env.

## Output

| Name | Mô tả |
|---|---|
| key_arn | ARN của KMS key |
| key_id | Key ID |
| alias_name | Tên alias |