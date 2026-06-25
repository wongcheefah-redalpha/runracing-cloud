# Production root: two active-active regional stacks (NA default provider, EU aliased),
# a global edge (CloudFront + WAF over the NA assets bucket, us-east-1), and the global
# routing + non-PII global tables. CODE/DESIGN ONLY - not applied.

module "na" {
  source = "./modules/regional_stack"

  name_prefix              = "${var.name_prefix}-na"
  region                   = var.na_region
  replay_retention_days    = var.replay_retention_days
  gamelift_build_s3_bucket = var.gamelift_build_s3_bucket
  gamelift_build_s3_key    = var.gamelift_build_s3_key
  gamelift_build_role_arn  = var.gamelift_build_role_arn
}

module "eu" {
  source    = "./modules/regional_stack"
  providers = { aws = aws.eu }

  name_prefix              = "${var.name_prefix}-eu"
  region                   = var.eu_region
  replay_retention_days    = var.replay_retention_days
  gamelift_build_s3_bucket = var.gamelift_build_s3_bucket
  gamelift_build_s3_key    = var.gamelift_build_s3_key
  gamelift_build_role_arn  = var.gamelift_build_role_arn
}

# Global edge over the NA assets bucket (CloudFront + WAF must be us-east-1 = default).
module "edge" {
  source = "../demo/terraform/modules/edge"

  name_prefix                   = "${var.name_prefix}-na"
  assets_bucket                 = module.na.assets_bucket
  assets_bucket_arn             = module.na.assets_bucket_arn
  assets_bucket_regional_domain = module.na.assets_bucket_regional_domain
}

# Global routing (Route 53 latency) + non-PII DynamoDB global tables.
module "global" {
  source = "./modules/global"

  name_prefix     = var.name_prefix
  domain_name     = var.domain_name
  na_region       = var.na_region
  eu_region       = var.eu_region
  na_api_hostname = module.na.api_hostname
  eu_api_hostname = module.eu.api_hostname
}
