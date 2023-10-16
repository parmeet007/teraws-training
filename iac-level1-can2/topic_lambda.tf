variable "common_sns_topic_arn" {
  description = "common Training SNS topic ARN"
  default     = "arn:aws:sns:us-east-1:000000007710:common-training-topic"
}

data "archive_file" "topic_lambda" {
  type        = "zip"
  source_file = "topic_lambda.py"
  output_path = "topic_lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "topic_lambda" {
  function_name = "topic_lambda_${var.unique_name}"
  handler       = "topic_lambda.lambda_handler"
  role          = aws_iam_role.topic_lambda_role.arn


  source_code_hash = data.archive_file.topic_lambda.output_base64sha256
  filename         = data.archive_file.topic_lambda.output_path
  runtime          = "python3.11"


  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.my_bucket.id
    }
  }
}

# IAM role for Lambda
resource "aws_iam_role" "topic_lambda_role" {
  name = "topic_lambda_role_${var.unique_name}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Subscribe Lambda function to existing SNS Topic
resource "aws_sns_topic_subscription" "topic_subscription" {
  topic_arn = var.common_sns_topic_arn  # Existing SNS topic ARN
  protocol  = "lambda"
  endpoint  = aws_lambda_function.topic_lambda.arn
}

# Permission for SNS to trigger Lambda
resource "aws_lambda_permission" "sns_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.topic_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.common_sns_topic_arn  # Existing SNS topic ARN
}

# Attach an IAM policy to Lambda to allow writing to S3
resource "aws_iam_role_policy_attachment" "s3_write_policy" {
  role       = aws_iam_role.topic_lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# cloudwatch
resource "aws_iam_role_policy_attachment" "topic_lambda_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.topic_lambda_role.name
}