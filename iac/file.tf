variable "file_name" {
  description = "my S3 bucket name"
  default     = "file4.txt"
}

resource "aws_s3_bucket_object" "my_object" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "SEND/${var.file_name}"
  source = "${var.file_name}"
  etag   = filemd5("${var.file_name}")
}
