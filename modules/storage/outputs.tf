# modules/storage/outputs.tf
# ---------------------------------------------------------------------------
# USE CASE: what the Lambdas need to reach the bucket (env var) and what IAM
# needs to scope the bucket policy to exactly this bucket.
# ---------------------------------------------------------------------------

output "bucket_name" {
  value = aws_s3_bucket.todos.id
}

output "bucket_arn" {
  value = aws_s3_bucket.todos.arn
}
