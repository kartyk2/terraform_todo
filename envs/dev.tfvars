# envs/dev.tfvars
# ---------------------------------------------------------------------------
# USE CASE: the dev deployment's inputs.
#   terraform apply -var-file=envs/dev.tfvars
#
# Copy this file to stage.tfvars / prod.tfvars when you deploy those; the
# Terraform code itself does not change between environments.
# ---------------------------------------------------------------------------

environment = "dev"
aws_region  = "us-west-2"

# No IdP wired up yet: the authorizer is not created, JWT routes deploy
# OPEN, and handlers fall back to the X-Tenant-Id header. Dev only.
jwt_issuer = null

lambda_timeout     = 10
log_retention_days = 7
