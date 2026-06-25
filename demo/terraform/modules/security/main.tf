# Security module: shared crypto (KMS CMK) and a Secrets Manager secret.
# Encryption at rest with a customer-managed key (SC-3); payment credentials
# stored as a secret, never in code (SC-4, D-6).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_kms_key" "main" {
  description             = "${var.name_prefix} data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

resource "aws_secretsmanager_secret" "payment" {
  name                    = "${var.name_prefix}-payment"
  description             = "Payment provider (Stripe) credentials - placeholder for the demo"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 0 # demo: allow immediate delete on destroy
}

resource "aws_secretsmanager_secret_version" "payment" {
  secret_id     = aws_secretsmanager_secret.payment.id
  secret_string = jsonencode({ stripe_api_key = "sk_test_placeholder_not_a_real_key" })
}
