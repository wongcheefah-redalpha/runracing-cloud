variable "name_prefix" {
  type        = string
  description = "Per-region resource name prefix (e.g. runracing-prod-na)."
}

variable "region" {
  type        = string
  description = "AWS region for this stack."
}

variable "replay_retention_days" {
  type        = number
  description = "Days to retain race replays (DR-3)."
  default     = 30
}

variable "gamelift_build_s3_bucket" {
  type        = string
  description = "S3 bucket holding the Unity dedicated-server build zip."
}

variable "gamelift_build_s3_key" {
  type        = string
  description = "S3 key of the server build zip."
}

variable "gamelift_build_role_arn" {
  type        = string
  description = "IAM role ARN GameLift assumes to read the build from S3."
}
