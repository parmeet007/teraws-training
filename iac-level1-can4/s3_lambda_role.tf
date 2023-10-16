resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy_${var.unique_name}"
  description = "Policy for allowing Lambda to access S3"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CopyObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}
