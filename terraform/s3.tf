environment = [
  {
    name  = "BUCKET_NAME"
    value = data.aws_s3_bucket.transaction_bucket.bucket
  },
  {
    name  = "INPUT_KEY"
    value = "input/transactions.csv"
  },
  {
    name  = "OUTPUT_KEY"
    value = "output/daily_transaction_summary.csv"
  }
]
