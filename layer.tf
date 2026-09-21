# layer.tf
# ---------------------------------------------------------------------------
# USE CASE: publishes src/shared/ as a Lambda layer so every function shares
# one copy of qe_common (response envelope, tenant resolution) instead of
# each package carrying its own.
#
# The layer zip must contain a top-level `python/` directory — that is the
# path the Python runtime adds to sys.path, which is why handlers can just
# `import qe_common`.
# ---------------------------------------------------------------------------

data "archive_file" "shared_layer" {
  type        = "zip"
  source_dir  = "${path.root}/src/shared"
  output_path = "${local.build_dir}/${local.name_prefix}-shared-layer.zip"
}

resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${local.name_prefix}-shared"
  description         = "qe_common: shared helpers for the QE API functions"
  filename            = data.archive_file.shared_layer.output_path
  source_code_hash    = data.archive_file.shared_layer.output_base64sha256 # forces a new version on change
  compatible_runtimes = ["python3.12"]
}
