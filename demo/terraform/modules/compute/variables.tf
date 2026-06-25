variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "players_table_name" {
  type        = string
  description = "DynamoDB players table name."
}

variable "players_table_arn" {
  type        = string
  description = "DynamoDB players table ARN."
}

variable "leaderboards_table_arn" {
  type        = string
  description = "DynamoDB leaderboards table ARN."
}

variable "replays_bucket" {
  type        = string
  description = "S3 replays bucket name."
}

variable "replays_bucket_arn" {
  type        = string
  description = "S3 replays bucket ARN."
}

variable "telemetry_stream_name" {
  type        = string
  description = "Kinesis telemetry stream name."
}

variable "telemetry_stream_arn" {
  type        = string
  description = "Kinesis telemetry stream ARN."
}

variable "secret_arn" {
  type        = string
  description = "Payment secret ARN."
}

variable "kms_key_arn" {
  type        = string
  description = "Shared CMK ARN."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the Lambda VPC config."
}

variable "lambda_sg_id" {
  type        = string
  description = "Security group ID for the Lambda."
}

variable "redis_endpoint" {
  type        = string
  description = "ElastiCache Redis primary endpoint (passed to the function env)."
}
