# VPC Module

Tạo VPC 2-tier (public + private subnet) cho EKS cluster, dùng chung cho môi trường dev và prod.

## Kiến trúc

- 1 VPC, mặc định 2 AZ (`ap-southeast-1a`, `ap-southeast-1b`)
- Public subnet: NAT Gateway, load balancer (ALB/NLB)
- Private subnet: EKS worker nodes, Vault, workload nội bộ
- Route: private subnet ra internet qua NAT Gateway đặt tại public subnet
- Security Group mặc định cho node-to-node communication

## NAT Gateway strategy

`single_nat_gateway = true` (default): 1 NAT Gateway duy nhất, cả 2 AZ share, tiết kiệm chi phí — phù hợp cho `dev`.
Set `single_nat_gateway = false` để mỗi AZ có NAT riêng, tăng HA — khuyến nghị cho `prod`.

## Sử dụng

```hcl
module "vpc" {
  source = "../../modules/vpc"

  environment           = "dev"
  vpc_cidr              = "10.0.0.0/16"
  azs                   = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  single_nat_gateway    = true
  cluster_name          = "capstone-eks-dev"

  tags = {
    Project = "capstone"
  }
}
```

## Input

| Name | Mô tả | Type | Default |
|---|---|---|---|
| environment | Tên môi trường (dev/prod) | string | - |
| vpc_cidr | CIDR block VPC | string | - |
| azs | Danh sách AZ | list(string) | ["ap-southeast-1a", "ap-southeast-1b"] |
| public_subnet_cidrs | CIDR public subnet | list(string) | - |
| private_subnet_cidrs | CIDR private subnet | list(string) | - |
| single_nat_gateway | Dùng 1 NAT thay vì 1 NAT/AZ | bool | true |
| cluster_name | Tên EKS cluster (tag subnet discovery) | string | - |
| tags | Tag chung | map(string) | {} |

## Output

| Name | Mô tả |
|---|---|
| vpc_id | ID VPC |
| vpc_cidr | CIDR VPC |
| public_subnet_ids | List ID public subnet |
| private_subnet_ids | List ID private subnet |
| nat_gateway_ids | List ID NAT Gateway |
| node_security_group_id | ID security group cho node |

## Lưu ý

- Tag `kubernetes.io/cluster/<cluster_name>` và `kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb` bắt buộc để EKS + AWS Load Balancer Controller tự động discover subnet.
- Module không tạo EKS cluster, chỉ chuẩn bị network layer.