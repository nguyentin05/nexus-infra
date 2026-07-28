output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = [for az in sort(keys(var.public_subnets)) : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  value = [for az in sort(keys(var.private_subnets)) : aws_subnet.private[az].id]
}

output "nat_gateway_ids" {
  value = [for az in sort(keys(var.public_subnets)) : aws_nat_gateway.this[az].id]
}

output "node_security_group_id" {
  value = aws_security_group.node_sg.id
}