variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "assets_bucket" {
  type        = string
  description = "Assets S3 bucket name (CloudFront origin)."
}

variable "assets_bucket_arn" {
  type        = string
  description = "Assets S3 bucket ARN."
}

variable "assets_bucket_regional_domain" {
  type        = string
  description = "Assets S3 bucket regional domain name."
}
