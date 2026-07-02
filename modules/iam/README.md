# IAM Module

Tạo IRSA (IAM Roles for Service Accounts) cho các add-on chạy trên EKS: AWS Load Balancer Controller, Karpenter, External DNS, Vault (KMS auto-unseal), EBS CSI Driver.

## Phụ thuộc

Nhận `oidc_provider_arn` và `oidc_provider_url` từ output của module `eks`. Module này không tự tạo OIDC provider — tách biệt trách nhiệm: `eks` sở hữu cluster + OIDC, `iam` chỉ sở hữu permission.

## Chuẩn bị trước khi apply

Copy JSON policy chính thức vào `policies/`:
- `lb_controller.json`: từ repo `kubernetes-sigs/aws-load-balancer-controller`
- `karpenter.json`: từ repo `aws/karpenter-provider-aws`

## Sử dụng

\`\`\`hcl
module "iam" {
  source = "../../modules/iam"

  environment        = "dev"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  vault_kms_key_arn  = module.kms.vault_key_arn

  tags = { Project = "capstone" }
}
\`\`\`

## Output

| Name | Mô tả |
|---|---|
| irsa_role_arns | Map role name => ARN (lb_controller, karpenter, external_dns, vault) |
| ebs_csi_role_arn | ARN role EBS CSI driver |

## Lưu ý

- `for_each` trên `local.irsa_roles` giúp thêm IRSA mới chỉ cần thêm 1 entry vào map, không cần viết resource mới.
- Service account name trong `assume_role_policy` phải khớp chính xác với `metadata.name` của ServiceAccount trong Helm chart tương ứng (annotate `eks.amazonaws.com/role-arn`).