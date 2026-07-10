terraform {
  backend "s3" {
    bucket       = "daily-transaction-processing-21492298"
    key          = "terraform/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}
