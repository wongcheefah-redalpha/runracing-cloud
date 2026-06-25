variable "name_prefix" {
  type        = string
  description = "Base name prefix for global resources."
}

variable "domain_name" {
  type        = string
  description = "Public DNS domain for the game APIs."
}

variable "na_region" {
  type        = string
  description = "North America region (for latency routing)."
}

variable "eu_region" {
  type        = string
  description = "Europe region (latency routing + DynamoDB replica)."
}

variable "na_api_hostname" {
  type        = string
  description = "North America regional API hostname."
}

variable "eu_api_hostname" {
  type        = string
  description = "Europe regional API hostname."
}
