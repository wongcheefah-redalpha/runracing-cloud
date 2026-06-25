# Analytics module: telemetry ingestion + anti-cheat path (FR-8, FR-9, FR-10, D-5, D-9).
# Kinesis stream -> (a) Firehose to the S3 data lake, (b) consumer Lambda (real-time
# stand-in for Managed Flink). Glue catalogs the lake; Athena queries it.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

locals {
  glue_db_name = replace("${var.name_prefix}_analytics", "-", "_")
}

# ----------------- Kinesis telemetry stream -----------------
resource "aws_kinesis_stream" "telemetry" {
  name             = "${var.name_prefix}-telemetry"
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

# ----------------- Firehose -> S3 data lake -----------------
data "aws_iam_policy_document" "firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.name_prefix}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

data "aws_iam_policy_document" "firehose" {
  statement {
    sid       = "ReadStream"
    effect    = "Allow"
    actions   = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
    resources = [aws_kinesis_stream.telemetry.arn]
  }
  statement {
    sid       = "WriteLake"
    effect    = "Allow"
    actions   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
    resources = [var.data_lake_bucket_arn, "${var.data_lake_bucket_arn}/*"]
  }
  statement {
    sid       = "Crypto"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:PutLogEvents", "logs:CreateLogStream"]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/kinesisfirehose/${var.name_prefix}-*:*"]
  }
}

resource "aws_iam_role_policy" "firehose" {
  name   = "${var.name_prefix}-firehose-access"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose.json
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name_prefix}-to-lake"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_kinesis_firehose_delivery_stream" "to_lake" {
  name        = "${var.name_prefix}-to-lake"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.telemetry.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = var.data_lake_bucket_arn
    prefix              = "telemetry/"
    error_output_prefix = "errors/"
    buffering_size      = 5
    buffering_interval  = 60
    compression_format  = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }

  depends_on = [aws_iam_role_policy.firehose]
}

# ----------------- Glue data catalog + crawler -----------------
data "aws_iam_policy_document" "glue_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${var.name_prefix}-glue"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_lake" {
  statement {
    sid       = "ReadLake"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.data_lake_bucket_arn, "${var.data_lake_bucket_arn}/*"]
  }
  statement {
    sid       = "Crypto"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "glue_lake" {
  name   = "${var.name_prefix}-glue-lake"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_lake.json
}

resource "aws_glue_catalog_database" "analytics" {
  name = local.glue_db_name
}

resource "aws_glue_crawler" "telemetry" {
  name          = "${var.name_prefix}-telemetry"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.analytics.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/telemetry/"
  }
}

# ----------------- Athena -----------------
resource "aws_athena_workgroup" "main" {
  name          = "${var.name_prefix}"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.data_lake_bucket}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }
  }
}

# ----------------- Consumer Lambda (real-time stand-in) -----------------
data "archive_file" "consumer" {
  type        = "zip"
  source_file = "${path.module}/src/consumer.py"
  output_path = "${path.module}/build/consumer.zip"
}

data "aws_iam_policy_document" "consumer_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consumer" {
  name               = "${var.name_prefix}-consumer"
  assume_role_policy = data.aws_iam_policy_document.consumer_assume.json
}

resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/lambda/${var.name_prefix}-consumer"
  retention_in_days = 14
}

data "aws_iam_policy_document" "consumer" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.consumer.arn}:*"]
  }
  statement {
    sid       = "ReadStream"
    effect    = "Allow"
    actions   = ["kinesis:DescribeStream", "kinesis:DescribeStreamSummary", "kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:ListShards", "kinesis:ListStreams", "kinesis:SubscribeToShard"]
    resources = [aws_kinesis_stream.telemetry.arn]
  }
  statement {
    sid       = "Crypto"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "${var.name_prefix}-consumer-access"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}

resource "aws_lambda_function" "consumer" {
  function_name    = "${var.name_prefix}-consumer"
  role             = aws_iam_role.consumer.arn
  runtime          = "python3.12"
  handler          = "consumer.lambda_handler"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout          = 30

  depends_on = [aws_cloudwatch_log_group.consumer, aws_iam_role_policy.consumer]
}

resource "aws_lambda_event_source_mapping" "consumer" {
  event_source_arn  = aws_kinesis_stream.telemetry.arn
  function_name     = aws_lambda_function.consumer.arn
  starting_position = "LATEST"
  batch_size        = 100
}
