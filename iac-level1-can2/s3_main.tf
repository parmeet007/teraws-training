provider "aws" {
  region = "us-east-1"
}

resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
}

variable "unique_name" {
  description = "my S3 bucket name"
  default     = "maybe-zzzz"
}


resource "aws_s3_bucket" "my_bucket" {
  bucket = var.unique_name

  tags = {
    Name        = var.unique_name
    Environment = "training"
  }
}
