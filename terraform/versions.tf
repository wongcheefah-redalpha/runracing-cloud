# Production stack: multi-region active-active (NA + EU), Asia-ready.
# CODE/DESIGN ONLY - not applied. Reuses the demo modules (under ../demo/terraform/modules)
# per region via provider aliases, and adds production-only global + GameLift modules.

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

# Default provider = North America launch region (also the home for CloudFront and
# CLOUDFRONT-scoped WAF, which must live in us-east-1).
provider "aws" {
  region = var.na_region
  default_tags {
    tags = {
      project    = "runracing"
      env        = "production"
      managed_by = "terraform"
    }
  }
}

# Europe launch region (GDPR residency home for EU player PII, D-11).
provider "aws" {
  alias  = "eu"
  region = var.eu_region
  default_tags {
    tags = {
      project    = "runracing"
      env        = "production"
      managed_by = "terraform"
    }
  }
}
