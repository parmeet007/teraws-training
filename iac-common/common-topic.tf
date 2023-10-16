provider "aws" {
  region = "us-east-1"
}

resource "aws_sns_topic" "example_topic" {
  name         = "common-training-topic"
  display_name = "Common Training Topic"
}
