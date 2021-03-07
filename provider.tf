provider "aws" {
  # assume_role {
  #     role_arn = "arn:aws:iam::${var.account_id}:role/devops"
  #     session_name = "terraform-app-${terraform.workspace}"
  # }
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}