data "aws_s3_bucket" "transaction_bucket" {
  bucket = "daily-transaction-processing-441661110146"
}

resource "aws_s3_object" "input_folder" {
  bucket = data.aws_s3_bucket.transaction_bucket.id
  key    = "input/"
}

resource "aws_s3_object" "output_folder" {
  bucket = data.aws_s3_bucket.transaction_bucket.id
  key    = "output/"
}
