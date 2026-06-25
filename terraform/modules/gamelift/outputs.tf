output "fleet_id" {
  value       = aws_gamelift_fleet.racing.id
  description = "GameLift fleet ID."
}

output "alias_arn" {
  value       = aws_gamelift_alias.racing.arn
  description = "GameLift alias ARN (stable target for blue-green fleet swaps)."
}

output "queue_name" {
  value       = aws_gamelift_game_session_queue.racing.name
  description = "GameLift game-session queue name (FlexMatch targets this out-of-band)."
}
