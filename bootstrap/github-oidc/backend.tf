terraform {
  backend "s3" {
    bucket       = "terraform-state-863547508328-ap-southeast-1-an"
    key          = "bootstrap/github-oidc/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
