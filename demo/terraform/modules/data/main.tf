# Data module: DynamoDB (players + leaderboards, region-scoped PII per D-11),
# S3 (replays/assets/data-lake), and ElastiCache Redis for real-time leaderboards
# (FR-4). Encryption at rest via the shared CMK (SC-3).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ----------------- DynamoDB -----------------
resource "aws_dynamodb_table" "players" {
  name         = "${var.name_prefix}-players"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "playerId"

  attribute {
    name = "playerId"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "leaderboards" {
  name         = "${var.name_prefix}-leaderboards"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "leaderboardId"
  range_key    = "playerRef"

  attribute {
    name = "leaderboardId"
    type = "S"
  }
  attribute {
    name = "playerRef"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
  point_in_time_recovery {
    enabled = true
  }
}

# ----------------- S3: replays (CMK) -----------------
resource "aws_s3_bucket" "replays" {
  bucket        = "${var.name_prefix}-replays-${var.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "replays" {
  bucket = aws_s3_bucket.replays.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replays" {
  bucket = aws_s3_bucket.replays.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "replays" {
  bucket                  = aws_s3_bucket.replays.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "replays" {
  bucket = aws_s3_bucket.replays.id
  rule {
    id     = "expire-replays"
    status = "Enabled"
    filter {}
    expiration {
      days = var.replay_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_bucket_policy" "replays_tls" {
  bucket = aws_s3_bucket.replays.id
  policy = data.aws_iam_policy_document.deny_insecure_replays.json
}

data "aws_iam_policy_document" "deny_insecure_replays" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.replays.arn, "${aws_s3_bucket.replays.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ----------------- S3: assets (SSE-S3 for CloudFront/OAC) -----------------
resource "aws_s3_bucket" "assets" {
  bucket        = "${var.name_prefix}-assets-${var.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------- S3: analytics data lake (CMK) -----------------
resource "aws_s3_bucket" "data_lake" {
  bucket        = "${var.name_prefix}-data-lake-${var.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------- ElastiCache Redis (real-time leaderboards) -----------------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.name_prefix}-redis"
  description                = "Real-time leaderboards (FR-4)"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [var.elasticache_sg_id]
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
}
