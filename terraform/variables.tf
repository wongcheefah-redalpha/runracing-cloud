variable "na_region" {
  description = "North America launch region."
  type        = string
  default     = "us-east-1"
}

variable "eu_region" {
  description = "Europe launch region (EU PII residency home, D-11)."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Base name prefix; region suffix is appended per regional stack."
  type        = string
  default     = "runracing-prod"
}

variable "replay_retention_days" {
  description = "Days to retain race replays (DR-3)."
  type        = number
  default     = 30
}

variable "domain_name" {
  description = "Public DNS domain for the game APIs (Route 53 latency routing)."
  type        = string
  default     = "runracing.example.com"
}

variable "gamelift_build_s3_bucket" {
  description = "S3 bucket holding the Unity dedicated-server build zip (per region)."
  type        = string
  default     = "REPLACE_WITH_BUILD_BUCKET"
}

variable "gamelift_build_s3_key" {
  description = "S3 key of the Unity dedicated-server build zip."
  type        = string
  default     = "builds/runracing-server.zip"
}

variable "gamelift_build_role_arn" {
  description = "IAM role ARN GameLift assumes to read the build from S3."
  type        = string
  default     = "REPLACE_WITH_BUILD_ACCESS_ROLE_ARN"
}
