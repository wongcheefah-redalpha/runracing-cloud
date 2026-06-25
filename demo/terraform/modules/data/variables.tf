variable "name_prefix" {
  description = "Prefix for resource names (e.g. runracing-demo)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to make S3 bucket names globally unique."
  type        = string
}

variable "replay_retention_days" {
  description = "Days to retain race replays before lifecycle expiration (DR-3)."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "ARN of the shared CMK for encryption at rest."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ElastiCache subnet group."
  type        = list(string)
}

variable "elasticache_sg_id" {
  description = "Security group ID for ElastiCache."
  type        = string
}

variable "force_destroy" {
  description = "Allow non-empty S3 buckets to be destroyed (demo convenience; false in prod)."
  type        = bool
  default     = false
}
