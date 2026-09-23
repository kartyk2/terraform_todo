# modules/storage/main.tf
# ---------------------------------------------------------------------------
# USE CASE: the S3 bucket that holds todos.csv — the entire "database" for
# this app. One object per environment, private, versioned so a bad write
# is recoverable and to satisfy the conditional-write (ETag) pattern the
# handlers rely on for concurrency control (see src/shared/python/csv_store.py).
# ---------------------------------------------------------------------------

# The bucket itself. Name resolves to "<project>-<environment>-todos", e.g.
# "qe-api-dev-todos" for the dev deploy (var.name_prefix is passed in from
# root main.tf as local.name_prefix = "${var.project}-${var.environment}").
# Bucket names are globally unique across all of AWS, not just this account —
# if this ever collides, that's why.
resource "aws_s3_bucket" "todos" {
  bucket = "${var.name_prefix}-todos"
}

# Keeps every prior version of todos.csv instead of overwriting in place.
# Two things this buys us:
#   1. a bad write (bug, bad deploy) is recoverable — roll back to a prior
#      version in the console or with `aws s3api list-object-versions`.
#   2. it's what makes the ETag on GetObject meaningful across writes, which
#      csv_store.py depends on for its If-Match / If-None-Match conditional
#      PutObject calls (its optimistic-concurrency check).
resource "aws_s3_bucket_versioning" "todos" {
  bucket = aws_s3_bucket.todos.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypts every object at rest with an AWS-managed key (SSE-S3). Applies
# automatically to every PutObject — csv_store.py does not need to (and
# does not) request encryption itself.
resource "aws_s3_bucket_server_side_encryption_configuration" "todos" {
  bucket = aws_s3_bucket.todos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Belt-and-suspenders against this bucket ever becoming reachable from the
# public internet. All four flags default to true in AWS today, but this
# stack sets them explicitly rather than relying on the provider default —
# a future default change should not silently reopen the bucket.
resource "aws_s3_bucket_public_access_block" "todos" {
  bucket = aws_s3_bucket.todos.id

  # Refuse any PUT that tries to attach a public-granting ACL to the bucket
  # or an object in it. Does not touch ACLs that already exist.
  block_public_acls = true

  # For any ACL that is already public (e.g. left over from before this
  # block existed), tell S3 to disregard the public grant when deciding
  # whether to serve a request. Pairs with block_public_acls above.
  ignore_public_acls = true

  # Refuse to save a bucket policy (the IAM-style JSON document) if it would
  # make the bucket or its objects public.
  block_public_policy = true

  # Even if a public policy is somehow already attached, restrict access to
  # AWS services and this account only — outside callers are blocked
  # regardless of what the policy says.
  restrict_public_buckets = true
}
