# Remote state in S3 with native S3 locking (use_lockfile; created by ../../bootstrap).
# Backend config cannot use variables; the bucket name is account-specific.
terraform {
  backend "s3" {
    bucket       = "runracing-tfstate-224848431296"
    key          = "demo/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
