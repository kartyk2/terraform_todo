# modules/storage/main.tf
# ---------------------------------------------------------------------------
# USE CASE: the S3 bucket that holds todos.csv — the entire "database" for
# this app. One object per environment, private, versioned so a bad write
# is recoverable and to satisfy the conditional-write (ETag) pattern the
# handlers rely on for concurrency control (see src/shared/python/csv_store.py).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "todos" {
  bucket = "${var.name_prefix}-todos"
}

resource "aws_s3_bucket_versioning" "todos" {
  bucket = aws_s3_bucket.todos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "todos" {
  bucket = aws_s3_bucket.todos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "todos" {
  bucket                  = aws_s3_bucket.todos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
