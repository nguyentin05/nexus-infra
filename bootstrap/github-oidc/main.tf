provider "aws" {
  region = "ap-southeast-1"
}

locals {
  github_oidc_provider_url = "https://token.actions.githubusercontent.com"

  common_tags = {
    Project   = "major"
    ManagedBy = "terraform"
  }
}

data "tls_certificate" "github_actions" {
  url = local.github_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = local.github_oidc_provider_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name   = "github-actions"
    Module = "github-oidc"
  })
}
