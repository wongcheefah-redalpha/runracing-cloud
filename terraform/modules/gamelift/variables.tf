variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "build_s3_bucket" {
  type        = string
  description = "S3 bucket holding the Unity dedicated-server build zip."
}

variable "build_s3_key" {
  type        = string
  description = "S3 key of the server build zip."
}

variable "build_role_arn" {
  type        = string
  description = "IAM role ARN GameLift assumes to read the build from S3."
}

variable "build_version" {
  type        = string
  description = "Build version label."
  default     = "1.0.0"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the fleet."
  default     = "c5.large"
}

variable "concurrent_sessions_per_host" {
  type        = number
  description = "Concurrent game-server processes per host."
  default     = 10
}
