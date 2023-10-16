provider "aws" {
  region = "us-east-1"
}

variable "user_identifier" {
  description = "my S3 bucket name"
  default     = "jacob"
}

# DynamoDB table for storing chat messages
resource "aws_dynamodb_table" "chat_table" {
  name         = "ChatTable_${var.user_identifier}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "timestamp"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

data "archive_file" "lambda_post_zip" {
  type        = "zip"
  source_file = "lambda_post_message.py"
  output_path = "lambda_post_message.zip"
}
# Lambda Function to post message
resource "aws_lambda_function" "lambda_post_message" {
  function_name    = "lambda_post_message_${var.user_identifier}"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = data.archive_file.lambda_post_zip.output_base64sha256
  filename         = data.archive_file.lambda_post_zip.output_path
  handler          = "lambda_post_message.lambda_handler"
  runtime          = "python3.11"

  environment {
    variables = {
      USER_IDENTIFIER = var.user_identifier
    }
  }
}

data "archive_file" "lambda_receive_zip" {
  type        = "zip"
  source_file = "lambda_receive_message.py"
  output_path = "lambda_receive_message.zip"
}
# Lambda Function to receive messages
resource "aws_lambda_function" "receive_message_lambda" {
  function_name    = "lambda_receive_message_${var.user_identifier}"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = data.archive_file.lambda_receive_zip.output_base64sha256
  filename         = data.archive_file.lambda_receive_zip.output_path
  handler          = "lambda_receive_message.lambda_handler"
  runtime          = "python3.11"

  environment {
    variables = {
      USER_IDENTIFIER = var.user_identifier
    }
  }
}

# Lambda Function to fetch messages
data "archive_file" "lambda_fetch_all_zip" {
  type        = "zip"
  source_file = "lambda_fetch_messages.py"
  output_path = "lambda_fetch_messages.zip"
}
resource "aws_lambda_function" "lambda_fetch_all_messages" {
  function_name    = "lambda_fetch_messages_${var.user_identifier}"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = data.archive_file.lambda_fetch_all_zip.output_base64sha256
  filename         = data.archive_file.lambda_fetch_all_zip.output_path
  handler          = "lambda_fetch_messages.lambda_handler"
  runtime          = "python3.11"

  environment {
    variables = {
      DYNAMODB_TABLE = "ChatTable_${var.user_identifier}"
    }
  }
}

# Lambda SNS invoke permission
resource "aws_lambda_permission" "sns_invoke_lambda_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receive_message_lambda.function_name
  principal     = "sns.amazonaws.com"

  source_arn = "arn:aws:sns:us-east-1:000000007710:common-training-topic"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role_${var.user_identifier}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy to allow Lambda functions to access DynamoDB and SNS
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "sns:Publish",
          "sns:Subscribe",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Subscribe Lambda function to the SNS Topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = "arn:aws:sns:us-east-1:000000007710:common-training-topic"
  protocol  = "lambda"
  endpoint  = aws_lambda_function.receive_message_lambda.arn
}


# Create REST API
resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "ChatAPI_${var.user_identifier}"
  description = "API for Chat Application"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Root Resource
resource "aws_api_gateway_resource" "api_gateway_root_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "chat"
}

# API Gateway Method for POST
resource "aws_api_gateway_method" "post_chat_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration between Lambda and API Gateway for POST
resource "aws_api_gateway_integration" "lambda_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method = aws_api_gateway_method.post_chat_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_post_message.invoke_arn
}

# Lambda API Gateway invoke permission
resource "aws_lambda_permission" "invoke_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_post_message.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.post_chat_method.http_method}${aws_api_gateway_resource.api_gateway_root_resource.path}"
}

# API Gateway Method for GET (fetch all messages)
resource "aws_api_gateway_method" "get_chat_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration between Lambda and API Gateway for GET
resource "aws_api_gateway_integration" "lambda_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.api_gateway_root_resource.id
  http_method = aws_api_gateway_method.get_chat_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_fetch_all_messages.invoke_arn
}

# Lambda API Gateway invoke permission for GET
resource "aws_lambda_permission" "invoke_get_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayForGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_fetch_all_messages.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.get_chat_method.http_method}${aws_api_gateway_resource.api_gateway_root_resource.path}"
}

# Deployment
resource "aws_api_gateway_deployment" "chat_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_post_integration,
    aws_api_gateway_integration.lambda_get_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  stage_name  = "test"
}

