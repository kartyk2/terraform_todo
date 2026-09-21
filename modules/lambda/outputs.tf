# modules/lambda/outputs.tf
# ---------------------------------------------------------------------------
# USE CASE: what api.tf needs to wire this function to a route —
# invoke_arn for the integration, function_name for the invoke permission.
# ---------------------------------------------------------------------------

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "Used as the API Gateway integration URI."
  value       = aws_lambda_function.this.invoke_arn
}
