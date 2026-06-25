output "hosted_zone_id" {
  value       = aws_route53_zone.main.zone_id
  description = "Route 53 hosted zone ID."
}

output "api_fqdn" {
  value       = "api.${var.domain_name}"
  description = "Latency-routed API FQDN."
}

output "sessions_table" {
  value       = aws_dynamodb_table.sessions.name
  description = "Non-PII sessions global table name."
}

output "matchmaking_table" {
  value       = aws_dynamodb_table.matchmaking.name
  description = "Non-PII matchmaking global table name."
}
