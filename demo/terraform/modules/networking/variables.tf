variable "name_prefix" {
  description = "Prefix for resource names (e.g. runracing-demo)."
  type        = string
}

variable "region" {
  description = "AWS region (used for gateway endpoint service names)."
  type        = string
}
