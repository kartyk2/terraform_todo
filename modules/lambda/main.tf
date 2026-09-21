# modules/lambda/main.tf
# ---------------------------------------------------------------------------
# USE CASE: one Lambda function — its zip, its log group, the function.
#
# This is the only module in the stack, and it exists because it is called
# once per endpoint. Everything single-use lives in root .tf files instead.
# Keep it thin: anything endpoint-specific belongs in locals.tf, not here.
# ---------------------------------------------------------------------------

# Zipped at plan time. source_code_hash below is what makes Terraform notice
# a code change and redeploy the function.
data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${var.build_dir}/${var.name}.zip"
}

# Created explicitly rather than letting Lambda create it on first invoke,
# so retention is managed and the group is destroyed with the stack.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = var.role_arn
  handler       = "handler.handler" # module.function inside the zip
  runtime       = "python3.12"

  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  timeout     = var.timeout
  memory_size = var.memory_size
  layers      = var.layers

  environment {
    variables = var.environment
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
