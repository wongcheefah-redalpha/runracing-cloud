# Compute module: API Lambda (in VPC) + its least-privilege role + HTTP API Gateway.

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

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/build/handler.zip"
}

# --- Execution role (least privilege) ---
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${var.name_prefix}-api-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# ENI management for VPC access + basic logs.
resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "api" {
  statement {
    sid       = "PlayerData"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
    resources = [var.players_table_arn, var.leaderboards_table_arn]
  }
  statement {
    sid       = "Replays"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.replays_bucket_arn}/*"]
  }
  statement {
    sid       = "Telemetry"
    effect    = "Allow"
    actions   = ["kinesis:PutRecord", "kinesis:PutRecords"]
    resources = [var.telemetry_stream_arn]
  }
  statement {
    sid       = "Secret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }
  statement {
    sid       = "Crypto"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "${var.name_prefix}-api-access"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}

# --- Function ---
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.name_prefix}-api"
  retention_in_days = 14
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.name_prefix}-api"
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      TABLE_NAME     = var.players_table_name
      REPLAY_BUCKET  = var.replays_bucket
      STREAM_NAME    = var.telemetry_stream_name
      SECRET_ARN     = var.secret_arn
      REDIS_ENDPOINT = var.redis_endpoint
    }
  }

  depends_on = [aws_cloudwatch_log_group.api, aws_iam_role_policy.api, aws_iam_role_policy_attachment.vpc]
}

# --- HTTP API ---
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-http"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# --- Observability: alarm on API Lambda errors (NFR-8) ---
resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.name_prefix}-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "API Lambda reported function errors"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
}
