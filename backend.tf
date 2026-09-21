# backend.tf
# ---------------------------------------------------------------------------
# USE CASE: decides where Terraform state lives.
#
# Right now state is LOCAL (terraform.tfstate in this directory), which is
# fine for one person on a laptop. Uncomment the block below and re-run
# `terraform init -migrate-state` before a second person touches this stack,
# otherwise you will get concurrent applies and a corrupted state file.
# ---------------------------------------------------------------------------

# terraform {
#   backend "s3" {
#     bucket         = "cozeva-tfstate"
#     key            = "qe-api/dev/terraform.tfstate"
#     region         = "us-west-2"
#     dynamodb_table = "cozeva-tfstate-lock"
#     encrypt        = true
#   }
# }
