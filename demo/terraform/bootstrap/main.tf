# Bootstrap: remote Terraform state backend (S3 bucket only).
# State locking uses S3 native locking (use_lockfile) in the env backends, so no
# DynamoDB lock table is needed. Uses LOCAL state itself (chicken-and-egg).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project    = "runracing"
      managed_by = "terraform"
      component  = "tf-state"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket = "runracing-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

