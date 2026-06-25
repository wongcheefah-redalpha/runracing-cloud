output "na_api_endpoint" {
  description = "North America regional API endpoint."
  value       = module.na.api_endpoint
}

output "eu_api_endpoint" {
  description = "Europe regional API endpoint."
  value       = module.eu.api_endpoint
}

output "api_fqdn" {
  description = "Latency-routed API FQDN (Route 53)."
  value       = module.global.api_fqdn
}

output "cloudfront_domain" {
  description = "Global CloudFront distribution domain (assets/replays)."
  value       = module.edge.cloudfront_domain
}

output "sessions_global_table" {
  description = "Non-PII sessions DynamoDB global table."
  value       = module.global.sessions_table
}

output "matchmaking_global_table" {
  description = "Non-PII matchmaking DynamoDB global table."
  value       = module.global.matchmaking_table
}

output "na_gamelift_queue" {
  description = "NA GameLift game-session queue."
  value       = module.na.gamelift_queue
}

output "eu_gamelift_queue" {
  description = "EU GameLift game-session queue."
  value       = module.eu.gamelift_queue
}
