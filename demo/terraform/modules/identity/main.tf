# Identity module: Amazon Cognito user pool + app client for player authentication (FR-3).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_cognito_user_pool" "main" {
  name                     = "${var.name_prefix}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # MFA optional (software token) - supports stronger account security.
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.name_prefix}-app"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false # public mobile client (no client secret)
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}
