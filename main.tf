provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3     = "http://localhost:4566"
    iam    = "http://localhost:4566"
    lambda = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "s3_start" {
  bucket = "s3-start"
}

resource "aws_s3_bucket" "s3_finish" {
  bucket = "s3-finish"
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.s3_start.id

  rule {
    id     = "expire_rule"
    status = "Enabled"

    filter {} # пустий фільтр — для всіх об'єктів

    expiration {
      days = 365
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.s3_start.arn}/*",
          "${aws_s3_bucket.s3_finish.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "copy_lambda" {
  filename         = "lambda.zip"
  function_name    = "copyS3Files"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      SOURCE_BUCKET      = aws_s3_bucket.s3_start.bucket
      DEST_BUCKET        = aws_s3_bucket.s3_finish.bucket
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_start.arn
}

resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = aws_s3_bucket.s3_start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
