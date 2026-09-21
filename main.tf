# main.tf
# ---------------------------------------------------------------------------
# USE CASE: creates the storage bucket, then one Lambda per entry in
# local.functions.
#
# This is the whole "application" wiring. To add an endpoint you do NOT
# touch this file: add a directory under src/functions/ and an entry in
# locals.tf.
# ---------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"

  name_prefix = local.name_prefix
}

module "lambda" {
  source   = "./modules/lambda"
  for_each = local.functions

  name        = "${local.name_prefix}-${each.key}"
  source_dir  = "${path.root}/src/functions/${each.key}"
  role_arn    = aws_iam_role.lambda.arn
  layers      = [aws_lambda_layer_version.shared.arn]
  environment = local.lambda_environment

  timeout            = var.lambda_timeout
  memory_size        = var.lambda_memory_size
  log_retention_days = var.log_retention_days
  build_dir          = local.build_dir
}
