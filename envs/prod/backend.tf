terraform {
  backend "s3" {
    bucket       = "terraform-state-863547508328-ap-southeast-1-an"
    key          = "envs/prod/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
