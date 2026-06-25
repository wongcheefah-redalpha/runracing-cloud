output "state_bucket" {
  description = "S3 bucket holding remote Terraform state (locking via S3 use_lockfile)."
  value       = aws_s3_bucket.state.id
}
