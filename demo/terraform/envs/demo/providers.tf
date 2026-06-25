terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

# Credentials come from the AWS_PROFILE env var (runracing-deployer) at runtime,
# so the code stays portable across accounts/CI.
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project    = "runracing"
      env        = "demo"
      managed_by = "terraform"
    }
  }
}
