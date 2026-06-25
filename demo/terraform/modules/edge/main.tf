# Edge module: CloudFront distribution (assets origin via Origin Access Control)
# fronted by an AWS WAFv2 web ACL (SC-6). CloudFront-scoped WAF must live in
# us-east-1, which is this stack's region.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-cf"
  description = "Edge protection for the CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSCommon"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-cf"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "${var.name_prefix}-assets-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "assets" {
  enabled         = true
  comment         = "${var.name_prefix} assets/replays CDN"
  web_acl_id      = aws_wafv2_web_acl.main.arn
  price_class     = "PriceClass_100"
  is_ipv6_enabled = true

  origin {
    domain_name              = var.assets_bucket_regional_domain
    origin_id                = "assets-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  default_cache_behavior {
    target_origin_id       = "assets-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Allow only this CloudFront distribution to read the assets bucket (OAC).
data "aws_iam_policy_document" "assets_oac" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.assets_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.assets.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "assets_oac" {
  bucket = var.assets_bucket
  policy = data.aws_iam_policy_document.assets_oac.json
}
