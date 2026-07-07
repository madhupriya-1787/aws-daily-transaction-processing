resource "aws_s3_bucket" "transaction_bucket" {
  bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

resource "aws_s3_object" "input_folder" {
  bucket = aws_s3_bucket.transaction_bucket.id
  key    = "input/"
}

resource "aws_s3_object" "output_folder" {
  bucket = aws_s3_bucket.transaction_bucket.id
  key    = "output/"
}

data "aws_caller_identity" "current" {}
