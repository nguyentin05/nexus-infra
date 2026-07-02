variable "public_access_cidrs" {
  description = "CIDRs allowed to access EKS public endpoint. Restrict in prod."
  type        = list(string)
}
