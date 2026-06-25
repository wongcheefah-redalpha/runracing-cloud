output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.assets.domain_name
  description = "CloudFront distribution domain name."
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.assets.id
  description = "CloudFront distribution ID."
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "WAFv2 web ACL ARN."
}
