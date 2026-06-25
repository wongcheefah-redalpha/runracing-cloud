# Global module: cross-region routing (Route 53 latency records) and DynamoDB global
# tables for non-PII data (sessions, matchmaking) per D-11 / NFR-6. PII tables stay
# region-scoped inside each regional stack.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# --- Route 53 latency-based routing to the regional API endpoints ---
# Note: production fronts each region with an API Gateway custom domain; the records
# below point at the regional API hostnames to express the latency-routing design.
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "api_na" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "na"
  records        = [var.na_api_hostname]

  latency_routing_policy {
    region = var.na_region
  }
}

resource "aws_route53_record" "api_eu" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "eu"
  records        = [var.eu_api_hostname]

  latency_routing_policy {
    region = var.eu_region
  }
}

# --- DynamoDB global tables (non-PII, multi-region multi-active) ---
resource "aws_dynamodb_table" "sessions" {
  name             = "${var.name_prefix}-sessions"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "sessionId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "sessionId"
    type = "S"
  }
  server_side_encryption {
    enabled = true
  }
  point_in_time_recovery {
    enabled = true
  }
  replica {
    region_name = var.eu_region
  }
}

resource "aws_dynamodb_table" "matchmaking" {
  name             = "${var.name_prefix}-matchmaking"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "ticketId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "ticketId"
    type = "S"
  }
  server_side_encryption {
    enabled = true
  }
  point_in_time_recovery {
    enabled = true
  }
  replica {
    region_name = var.eu_region
  }
}
