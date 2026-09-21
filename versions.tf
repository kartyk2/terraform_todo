# versions.tf
# ---------------------------------------------------------------------------
# USE CASE: pins the Terraform CLI and AWS provider versions. Nothing is
# created here.
#
# ---------------------------------------------------------------------------
# HOW PROVIDER VERSION MAINTENANCE WORKS
# ---------------------------------------------------------------------------
# Two files control it, and they do different jobs:
#
#   versions.tf (this file)  the ALLOWED RANGE.  "~> 5.0" means >= 5.0, < 6.0
#                            — accept any 5.x, never auto-jump to 6.0, since
#                            a major bump can rename or remove resources.
#
#   .terraform.lock.hcl      the EXACT VERSION actually used, plus checksums.
#                            Written by `terraform init`. COMMIT IT: it is
#                            what makes your laptop and CI resolve the same
#                            provider build. Without it, two people inside
#                            the same "~> 5.0" range can get different 5.x.
#
# To take a newer provider inside the range:   terraform init -upgrade
# To move to a new major:  widen the constraint here, `terraform init
# -upgrade`, then read `terraform plan` carefully before applying — expect
# renamed arguments and occasional forced replacements.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" } # zips the Lambda source
  }
}
