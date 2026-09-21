# outputs.tf
# ---------------------------------------------------------------------------
# USE CASE: what you need after `terraform apply` — the base URL to curl,
# the bucket to peek at with `aws s3 cp`, and the route map.
# ---------------------------------------------------------------------------

output "api_base_url" {
  description = "Append /api/v1/todos to reach the API."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "todos_bucket" {
  description = "S3 bucket holding todos.csv — the entire database."
  value       = module.storage.bucket_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "routes" {
  description = "Route key -> function name, exactly as API Gateway has it."
  value       = { for k, f in local.http_functions : f.route => module.lambda[k].function_name }
}
