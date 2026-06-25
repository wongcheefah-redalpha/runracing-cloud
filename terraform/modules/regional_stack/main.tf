# Regional stack: one full active-active region. Reuses the demo modules
# (networking, security/KMS, data, compute, analytics) and adds GameLift.
# The default aws provider is supplied by the caller (root) per region.

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

data "aws_caller_identity" "current" {}

module "networking" {
  source      = "../../../demo/terraform/modules/networking"
  name_prefix = var.name_prefix
  region      = var.region
}

module "security" {
  source      = "../../../demo/terraform/modules/security"
  name_prefix = var.name_prefix
}

module "data" {
  source                = "../../../demo/terraform/modules/data"
  name_prefix           = var.name_prefix
  account_id            = data.aws_caller_identity.current.account_id
  replay_retention_days = var.replay_retention_days
  kms_key_arn           = module.security.kms_key_arn
  private_subnet_ids    = module.networking.private_subnet_ids
  elasticache_sg_id     = module.networking.elasticache_sg_id
  force_destroy         = false # production: protect data
}

module "analytics" {
  source               = "../../../demo/terraform/modules/analytics"
  name_prefix          = var.name_prefix
  region               = var.region
  account_id           = data.aws_caller_identity.current.account_id
  kms_key_arn          = module.security.kms_key_arn
  data_lake_bucket     = module.data.data_lake_bucket
  data_lake_bucket_arn = module.data.data_lake_bucket_arn
}

module "compute" {
  source                 = "../../../demo/terraform/modules/compute"
  name_prefix            = var.name_prefix
  players_table_name     = module.data.players_table_name
  players_table_arn      = module.data.players_table_arn
  leaderboards_table_arn = module.data.leaderboards_table_arn
  replays_bucket         = module.data.replays_bucket
  replays_bucket_arn     = module.data.replays_bucket_arn
  telemetry_stream_name  = module.analytics.telemetry_stream_name
  telemetry_stream_arn   = module.analytics.telemetry_stream_arn
  secret_arn             = module.security.secret_arn
  kms_key_arn            = module.security.kms_key_arn
  private_subnet_ids     = module.networking.private_subnet_ids
  lambda_sg_id           = module.networking.lambda_sg_id
  redis_endpoint         = module.data.redis_primary_endpoint
}

module "gamelift" {
  source          = "../gamelift"
  name_prefix     = var.name_prefix
  build_s3_bucket = var.gamelift_build_s3_bucket
  build_s3_key    = var.gamelift_build_s3_key
  build_role_arn  = var.gamelift_build_role_arn
}
