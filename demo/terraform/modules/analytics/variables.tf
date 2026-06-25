variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "account_id" {
  type        = string
  description = "AWS account ID."
}

variable "kms_key_arn" {
  type        = string
  description = "Shared CMK ARN."
}

variable "data_lake_bucket" {
  type        = string
  description = "S3 data-lake bucket name."
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "S3 data-lake bucket ARN."
}
