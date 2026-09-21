# providers.tf
# ---------------------------------------------------------------------------
# USE CASE: configures the AWS provider — which region we deploy into, and
# the tags stamped onto every resource so cost and ownership are traceable.
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
