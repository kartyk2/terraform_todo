# variables.tf
# ---------------------------------------------------------------------------
# USE CASE: every knob this stack accepts from the outside. Values come from
# envs/<env>.tfvars, so the same code deploys to dev / stage / prod.
# Add a variable here the moment you find yourself hardcoding an env value.
# ---------------------------------------------------------------------------

variable "environment" {
  description = "dev | stage | prod. Becomes part of every resource name."
  type        = string
}

variable "project" {
  description = "Name prefix for all resources."
  type        = string
  default     = "qe-api"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "jwt_issuer" {
  description = <<-DESC
    OIDC issuer URL for the tenant authorizer.
    Null (the dev default) means NO authorizer is created and JWT routes
    deploy open — handlers then fall back to the X-Tenant-Id header.
    Never leave this null outside dev.
  DESC
  type        = string
  default     = null
}

variable "jwt_audience" {
  description = "Accepted `aud` claims. Only used when jwt_issuer is set."
  type        = list(string)
  default     = []
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "lambda_memory_size" {
  type    = number
  default = 256
}

variable "log_retention_days" {
  description = "Applies to both the Lambda log groups and the API access log."
  type        = number
  default     = 14
}
