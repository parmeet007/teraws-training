provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  description = "my S3 bucket name"
  default     = "bname"
}

resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.bucket_name}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.bucket_name}-${random_string.bucket_suffix.result}"
    Environment = "training"
  }
}
