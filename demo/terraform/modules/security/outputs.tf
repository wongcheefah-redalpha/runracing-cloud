output "kms_key_arn" {
  description = "ARN of the shared customer-managed KMS key."
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the shared customer-managed KMS key."
  value       = aws_kms_key.main.key_id
}

output "secret_arn" {
  description = "ARN of the payment-provider secret."
  value       = aws_secretsmanager_secret.payment.arn
}
