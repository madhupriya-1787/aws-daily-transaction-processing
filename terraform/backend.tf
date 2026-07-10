terraform {
  backend "s3" {
    bucket       = "daily-transaction-processing-<account-id>"
    key          = "terraform/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}
