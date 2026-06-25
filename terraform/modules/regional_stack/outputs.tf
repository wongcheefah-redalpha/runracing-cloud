output "api_endpoint" {
  value       = module.compute.api_endpoint
  description = "Regional HTTP API base endpoint."
}

output "api_hostname" {
  value       = replace(replace(module.compute.api_endpoint, "https://", ""), "/", "")
  description = "Regional HTTP API hostname (for Route 53 latency records)."
}

output "assets_bucket" {
  value       = module.data.assets_bucket
  description = "Regional assets S3 bucket name."
}

output "assets_bucket_arn" {
  value       = module.data.assets_bucket_arn
  description = "Regional assets S3 bucket ARN."
}

output "assets_bucket_regional_domain" {
  value       = module.data.assets_bucket_regional_domain
  description = "Regional assets S3 bucket regional domain name."
}

output "players_table_name" {
  value       = module.data.players_table_name
  description = "Regional (PII, region-scoped) players table name."
}

output "gamelift_queue" {
  value       = module.gamelift.queue_name
  description = "GameLift game-session queue name."
}
