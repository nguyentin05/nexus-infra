terraform {
  backend "s3" {
    bucket         = "terraform-state-065320271480-ap-southeast-1-an"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
