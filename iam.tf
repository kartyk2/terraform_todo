# iam.tf
# ---------------------------------------------------------------------------
# USE CASE: the single execution role all the Lambdas assume.
#
# Grants CloudWatch Logs, plus exactly the S3 actions csv_store.py needs on
# exactly the todos bucket: Get/PutObject to read and conditionally write
# todos.csv. No ListBucket, no other bucket, no "*" — a new resource has to
# be granted deliberately.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Log stream creation + writes. Everything else is a deliberate addition.
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_todos_csv" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${module.storage.bucket_arn}/todos.csv"]
  }
}

resource "aws_iam_role_policy" "lambda_todos_csv" {
  name   = "${local.name_prefix}-lambda-todos-csv"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_todos_csv.json
}
