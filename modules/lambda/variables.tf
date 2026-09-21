# modules/lambda/variables.tf
# ---------------------------------------------------------------------------
# USE CASE: the module's interface. Runtime and handler name are deliberately
# NOT variables — every function in this stack is python3.12 handler.handler,
# and keeping that fixed is what makes adding an endpoint a one-line change.
# ---------------------------------------------------------------------------

variable "name" {
  description = "Fully qualified function name, e.g. qe-api-dev-exe."
  type        = string
}

variable "source_dir" {
  description = "Directory containing handler.py; zipped at plan time."
  type        = string
}

variable "role_arn" {
  description = "Execution role, shared by all the API functions."
  type        = string
}

variable "build_dir" {
  description = "Where the generated zip is written."
  type        = string
}

variable "layers" {
  description = "Layer ARNs. The qe_common shared layer is passed in here."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment variables, e.g. table and bucket names."
  type        = map(string)
  default     = {}
}

variable "timeout" {
  type    = number
  default = 10
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "log_retention_days" {
  type    = number
  default = 14
}
