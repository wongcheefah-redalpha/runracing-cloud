variable "region" {
  description = "AWS region for the demo (us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "replay_retention_days" {
  description = "Days to retain race replays (DR-3)."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow non-empty S3 buckets to be destroyed (true for the short-lived demo)."
  type        = bool
  default     = true
}
