# Single-region (us-east-1) production-like demo. Mirrors the production data plane
# and edge as closely as is deployable. Components that require external artifacts
# or subscriptions (GameLift, Managed Flink, QuickSight) are documented in
# docs/04-deployment-log.md (Constraints & Omissions), not instantiated here.

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "runracing-demo"
}

module "networking" {
  source      = "../../modules/networking"
  name_prefix = local.name_prefix
  region      = var.region
}

module "security" {
  source      = "../../modules/security"
  name_prefix = local.name_prefix
}

module "data" {
  source                = "../../modules/data"
  name_prefix           = local.name_prefix
  account_id            = data.aws_caller_identity.current.account_id
  replay_retention_days = var.replay_retention_days
  kms_key_arn           = module.security.kms_key_arn
  private_subnet_ids    = module.networking.private_subnet_ids
  elasticache_sg_id     = module.networking.elasticache_sg_id
  force_destroy         = var.force_destroy
}

module "analytics" {
  source               = "../../modules/analytics"
  name_prefix          = local.name_prefix
  region               = var.region
  account_id           = data.aws_caller_identity.current.account_id
  kms_key_arn          = module.security.kms_key_arn
  data_lake_bucket     = module.data.data_lake_bucket
  data_lake_bucket_arn = module.data.data_lake_bucket_arn
}

module "compute" {
  source                 = "../../modules/compute"
  name_prefix            = local.name_prefix
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

module "edge" {
  source                        = "../../modules/edge"
  name_prefix                   = local.name_prefix
  assets_bucket                 = module.data.assets_bucket
  assets_bucket_arn             = module.data.assets_bucket_arn
  assets_bucket_regional_domain = module.data.assets_bucket_regional_domain
}
