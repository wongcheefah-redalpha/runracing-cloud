# Deployment Log — Production-Like Demo (single region, us-east-1)

This document records a single, clean-slate deployment run of the production-like
single-region demo (decision D-4, D-20) into AWS account 224848431296. The Terraform
code is under [../demo/terraform/](../demo/terraform/); demo scope, fidelity, and omissions are in
[03-architecture.md](03-architecture.md) Section 19.

Notes:

- Every Terraform command ran as the least-privilege IAM user `runracing-deployer`
  (never the account root, per D-10 / D-20), via `AWS_PROFILE=runracing-deployer`.
- State is in S3 with native S3 locking (`use_lockfile`, D-19); no DynamoDB lock table.
- ANSI color codes are stripped from captured output for readability.
- This log shows only the final clean-slate run (a fresh `init` that installs providers
  from scratch, then a from-nothing apply of all 70 resources).

---

## Prerequisites (one-time account setup, outside the clean run)

These exist before the run below and are not re-created by it:

1. **Least-privilege deployer.** Using the account root once, a dedicated IAM user
   `runracing-deployer` was created and scoped to only the services this stack uses
   (managed policies `runracing-deployer` and `runracing-deployer-2`): S3, DynamoDB,
   Lambda, Logs, API Gateway, Cognito, EC2/VPC, ElastiCache, Kinesis, Firehose, Glue,
   Athena, CloudFront, WAFv2, KMS, Secrets Manager, CloudWatch, and IAM limited to
   `runracing-*` roles/policies with `PassRole` only to the Lambda/Firehose/Glue service
   principals. Its access keys back the `runracing-deployer` CLI profile.
2. **ElastiCache service-linked role.** `AWSServiceRoleForElastiCache` was created once
   (`aws iam create-service-linked-role --aws-service-name elasticache.amazonaws.com`);
   ElastiCache requires it to exist in the account.
3. **Remote state backend.** An S3 bucket `runracing-tfstate-224848431296` (versioned,
   encrypted, public access blocked) created by the `demo/terraform/bootstrap` stack; the env
   backend uses it with native S3 locking.

---

## Step 1 — Clean-slate init (fresh provider install)

```bash
cd demo/terraform/envs/demo
rm -rf .terraform .terraform.lock.hcl     # ensure a true clean slate
AWS_PROFILE=runracing-deployer terraform init
```

```text
Initializing modules...
- analytics in ../../modules/analytics
- security in ../../modules/security
- networking in ../../modules/networking
- data in ../../modules/data
- edge in ../../modules/edge
- compute in ../../modules/compute
Initializing provider plugins found in the configuration...
- Finding hashicorp/archive versions matching ">= 2.4.0"...
- Finding hashicorp/aws versions matching ">= 5.0.0"...
- Installing hashicorp/archive v2.8.0...
- Installed hashicorp/archive v2.8.0 (signed by HashiCorp)
- Installing hashicorp/aws v6.52.0...
- Installed hashicorp/aws v6.52.0 (signed by HashiCorp)

Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins found in the state...

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
INIT_EXIT=0
```

---

## Step 2 — Validate

```bash
AWS_PROFILE=runracing-deployer terraform validate
```

```text
Success! The configuration is valid.

```

---

## Step 3 — Plan (70 resources to add)

```bash
AWS_PROFILE=runracing-deployer terraform plan -out=tfplan
```

```text
module.compute.data.archive_file.lambda: Reading...
module.analytics.data.archive_file.consumer: Reading...
module.analytics.data.archive_file.consumer: Read complete after 0s [id=8c98aeb23f404d74975dd61ee75469105a5142d3]
module.compute.data.archive_file.lambda: Read complete after 0s [id=1103583742115d813af906f81e43e1adfc62fe48]
module.analytics.data.aws_iam_policy_document.consumer_assume: Reading...
module.analytics.data.aws_iam_policy_document.firehose_assume: Reading...
module.analytics.data.aws_iam_policy_document.consumer_assume: Read complete after 0s [id=2690255455]
module.analytics.data.aws_iam_policy_document.firehose_assume: Read complete after 0s [id=414810265]
module.networking.data.aws_availability_zones.available: Reading...
module.analytics.data.aws_iam_policy_document.glue_assume: Reading...
data.aws_caller_identity.current: Reading...
module.compute.data.aws_iam_policy_document.assume: Reading...
module.analytics.data.aws_iam_policy_document.glue_assume: Read complete after 0s [id=2681768870]
module.compute.data.aws_iam_policy_document.assume: Read complete after 0s [id=2690255455]
data.aws_caller_identity.current: Read complete after 1s [id=224848431296]
module.networking.data.aws_availability_zones.available: Read complete after 2s [id=us-east-1]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # module.analytics.data.aws_iam_policy_document.consumer will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "consumer" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "logs:CreateLogStream",
              + "logs:PutLogEvents",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Logs"
        }
      + statement {
          + actions   = [
              + "kinesis:DescribeStream",
              + "kinesis:DescribeStreamSummary",
              + "kinesis:GetRecords",
              + "kinesis:GetShardIterator",
              + "kinesis:ListShards",
              + "kinesis:ListStreams",
              + "kinesis:SubscribeToShard",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "ReadStream"
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Crypto"
        }
    }

  # module.analytics.data.aws_iam_policy_document.firehose will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "firehose" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "kinesis:DescribeStream",
              + "kinesis:GetRecords",
              + "kinesis:GetShardIterator",
              + "kinesis:ListShards",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "ReadStream"
        }
      + statement {
          + actions   = [
              + "s3:AbortMultipartUpload",
              + "s3:GetBucketLocation",
              + "s3:GetObject",
              + "s3:ListBucket",
              + "s3:ListBucketMultipartUploads",
              + "s3:PutObject",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
              + (known after apply),
            ]
          + sid       = "WriteLake"
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
              + "kms:GenerateDataKey",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Crypto"
        }
      + statement {
          + actions   = [
              + "logs:CreateLogStream",
              + "logs:PutLogEvents",
            ]
          + effect    = "Allow"
          + resources = [
              + "arn:aws:logs:us-east-1:224848431296:log-group:/aws/kinesisfirehose/runracing-demo-*:*",
            ]
          + sid       = "Logs"
        }
    }

  # module.analytics.data.aws_iam_policy_document.glue_lake will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "glue_lake" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:GetObject",
              + "s3:ListBucket",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
              + (known after apply),
            ]
          + sid       = "ReadLake"
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
              + "kms:GenerateDataKey",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Crypto"
        }
    }

  # module.analytics.aws_athena_workgroup.main will be created
  + resource "aws_athena_workgroup" "main" {
      + arn           = (known after apply)
      + force_destroy = true
      + id            = (known after apply)
      + name          = "runracing-demo"
      + region        = "us-east-1"
      + state         = "ENABLED"
      + tags_all      = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + configuration {
          + enable_minimum_encryption_configuration = (known after apply)
          + enforce_workgroup_configuration         = true
          + publish_cloudwatch_metrics_enabled      = true
          + requester_pays_enabled                  = false

          + result_configuration {
              + output_location = (known after apply)

              + encryption_configuration {
                  + encryption_option = "SSE_KMS"
                  + kms_key_arn       = (known after apply)
                }
            }
        }
    }

  # module.analytics.aws_cloudwatch_log_group.consumer will be created
  + resource "aws_cloudwatch_log_group" "consumer" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/lambda/runracing-demo-consumer"
      + name_prefix                 = (known after apply)
      + region                      = "us-east-1"
      + retention_in_days           = 14
      + skip_destroy                = false
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.analytics.aws_cloudwatch_log_group.firehose will be created
  + resource "aws_cloudwatch_log_group" "firehose" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/kinesisfirehose/runracing-demo-to-lake"
      + name_prefix                 = (known after apply)
      + region                      = "us-east-1"
      + retention_in_days           = 14
      + skip_destroy                = false
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.analytics.aws_cloudwatch_log_stream.firehose will be created
  + resource "aws_cloudwatch_log_stream" "firehose" {
      + arn            = (known after apply)
      + id             = (known after apply)
      + log_group_name = "/aws/kinesisfirehose/runracing-demo-to-lake"
      + name           = "S3Delivery"
      + region         = "us-east-1"
    }

  # module.analytics.aws_glue_catalog_database.analytics will be created
  + resource "aws_glue_catalog_database" "analytics" {
      + arn          = (known after apply)
      + catalog_id   = (known after apply)
      + id           = (known after apply)
      + location_uri = (known after apply)
      + name         = "runracing_demo_analytics"
      + region       = "us-east-1"
      + tags_all     = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + create_table_default_permission (known after apply)
    }

  # module.analytics.aws_glue_crawler.telemetry will be created
  + resource "aws_glue_crawler" "telemetry" {
      + arn           = (known after apply)
      + database_name = "runracing_demo_analytics"
      + id            = (known after apply)
      + name          = "runracing-demo-telemetry"
      + region        = "us-east-1"
      + role          = (known after apply)
      + tags_all      = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + s3_target {
          + path = (known after apply)
        }
    }

  # module.analytics.aws_iam_role.consumer will be created
  + resource "aws_iam_role" "consumer" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "lambda.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "runracing-demo-consumer"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.analytics.aws_iam_role.firehose will be created
  + resource "aws_iam_role" "firehose" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "firehose.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "runracing-demo-firehose"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.analytics.aws_iam_role.glue will be created
  + resource "aws_iam_role" "glue" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "glue.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "runracing-demo-glue"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.analytics.aws_iam_role_policy.consumer will be created
  + resource "aws_iam_role_policy" "consumer" {
      + id          = (known after apply)
      + name        = "runracing-demo-consumer-access"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # module.analytics.aws_iam_role_policy.firehose will be created
  + resource "aws_iam_role_policy" "firehose" {
      + id          = (known after apply)
      + name        = "runracing-demo-firehose-access"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # module.analytics.aws_iam_role_policy.glue_lake will be created
  + resource "aws_iam_role_policy" "glue_lake" {
      + id          = (known after apply)
      + name        = "runracing-demo-glue-lake"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # module.analytics.aws_iam_role_policy_attachment.glue_service will be created
  + resource "aws_iam_role_policy_attachment" "glue_service" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
      + role       = "runracing-demo-glue"
    }

  # module.analytics.aws_kinesis_firehose_delivery_stream.to_lake will be created
  + resource "aws_kinesis_firehose_delivery_stream" "to_lake" {
      + arn            = (known after apply)
      + destination    = "extended_s3"
      + destination_id = (known after apply)
      + id             = (known after apply)
      + name           = "runracing-demo-to-lake"
      + region         = "us-east-1"
      + tags_all       = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + version_id     = (known after apply)

      + extended_s3_configuration {
          + bucket_arn          = (known after apply)
          + buffering_interval  = 60
          + buffering_size      = 5
          + compression_format  = "GZIP"
          + custom_time_zone    = "UTC"
          + error_output_prefix = "errors/"
          + prefix              = "telemetry/"
          + role_arn            = (known after apply)
          + s3_backup_mode      = "Disabled"

          + cloudwatch_logging_options {
              + enabled         = true
              + log_group_name  = "/aws/kinesisfirehose/runracing-demo-to-lake"
              + log_stream_name = "S3Delivery"
            }
        }

      + kinesis_source_configuration {
          + kinesis_stream_arn = (known after apply)
          + role_arn           = (known after apply)
        }
    }

  # module.analytics.aws_kinesis_stream.telemetry will be created
  + resource "aws_kinesis_stream" "telemetry" {
      + arn                       = (known after apply)
      + encryption_type           = "KMS"
      + enforce_consumer_deletion = false
      + id                        = (known after apply)
      + kms_key_id                = (known after apply)
      + max_record_size_in_kib    = (known after apply)
      + name                      = "runracing-demo-telemetry"
      + region                    = "us-east-1"
      + retention_period          = 24
      + tags_all                  = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + stream_mode_details {
          + stream_mode = "ON_DEMAND"
        }
    }

  # module.analytics.aws_lambda_event_source_mapping.consumer will be created
  + resource "aws_lambda_event_source_mapping" "consumer" {
      + arn                           = (known after apply)
      + batch_size                    = 100
      + enabled                       = true
      + event_source_arn              = (known after apply)
      + function_arn                  = (known after apply)
      + function_name                 = (known after apply)
      + id                            = (known after apply)
      + last_modified                 = (known after apply)
      + last_processing_result        = (known after apply)
      + maximum_record_age_in_seconds = (known after apply)
      + maximum_retry_attempts        = (known after apply)
      + parallelization_factor        = (known after apply)
      + region                        = "us-east-1"
      + starting_position             = "LATEST"
      + state                         = (known after apply)
      + state_transition_reason       = (known after apply)
      + tags_all                      = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + uuid                          = (known after apply)

      + amazon_managed_kafka_event_source_config (known after apply)

      + self_managed_kafka_event_source_config (known after apply)
    }

  # module.analytics.aws_lambda_function.consumer will be created
  + resource "aws_lambda_function" "consumer" {
      + architectures                  = (known after apply)
      + arn                            = (known after apply)
      + code_sha256                    = (known after apply)
      + filename                       = "../../modules/analytics/build/consumer.zip"
      + function_name                  = "runracing-demo-consumer"
      + handler                        = "consumer.lambda_handler"
      + id                             = (known after apply)
      + invoke_arn                     = (known after apply)
      + last_modified                  = (known after apply)
      + memory_size                    = 128
      + package_type                   = "Zip"
      + publish                        = false
      + qualified_arn                  = (known after apply)
      + qualified_invoke_arn           = (known after apply)
      + region                         = "us-east-1"
      + reserved_concurrent_executions = -1
      + response_streaming_invoke_arn  = (known after apply)
      + role                           = (known after apply)
      + runtime                        = "python3.12"
      + signing_job_arn                = (known after apply)
      + signing_profile_version_arn    = (known after apply)
      + skip_destroy                   = false
      + source_code_hash               = "C0WyfkyD6LvbEKtupytN4F3KQsJ2za1MKM5B65B1oV0="
      + source_code_size               = (known after apply)
      + tags_all                       = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + timeout                        = 30
      + version                        = (known after apply)

      + ephemeral_storage (known after apply)

      + logging_config (known after apply)

      + tracing_config (known after apply)
    }

  # module.compute.data.aws_iam_policy_document.api will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "api" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "dynamodb:GetItem",
              + "dynamodb:PutItem",
              + "dynamodb:Query",
              + "dynamodb:UpdateItem",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
              + (known after apply),
            ]
          + sid       = "PlayerData"
        }
      + statement {
          + actions   = [
              + "s3:GetObject",
              + "s3:PutObject",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Replays"
        }
      + statement {
          + actions   = [
              + "kinesis:PutRecord",
              + "kinesis:PutRecords",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Telemetry"
        }
      + statement {
          + actions   = [
              + "secretsmanager:GetSecretValue",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Secret"
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
              + "kms:GenerateDataKey",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "Crypto"
        }
    }

  # module.compute.aws_apigatewayv2_api.http will be created
  + resource "aws_apigatewayv2_api" "http" {
      + api_endpoint                 = (known after apply)
      + api_key_selection_expression = "$request.header.x-api-key"
      + arn                          = (known after apply)
      + execution_arn                = (known after apply)
      + id                           = (known after apply)
      + ip_address_type              = (known after apply)
      + name                         = "runracing-demo-http"
      + protocol_type                = "HTTP"
      + region                       = "us-east-1"
      + route_selection_expression   = "$request.method $request.path"
      + tags_all                     = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.compute.aws_apigatewayv2_integration.lambda will be created
  + resource "aws_apigatewayv2_integration" "lambda" {
      + api_id                                    = (known after apply)
      + connection_type                           = "INTERNET"
      + id                                        = (known after apply)
      + integration_response_selection_expression = (known after apply)
      + integration_type                          = "AWS_PROXY"
      + integration_uri                           = (known after apply)
      + payload_format_version                    = "2.0"
      + region                                    = "us-east-1"
      + timeout_milliseconds                      = (known after apply)
    }

  # module.compute.aws_apigatewayv2_route.health will be created
  + resource "aws_apigatewayv2_route" "health" {
      + api_id             = (known after apply)
      + api_key_required   = false
      + authorization_type = "NONE"
      + id                 = (known after apply)
      + region             = "us-east-1"
      + route_key          = "GET /health"
      + target             = (known after apply)
    }

  # module.compute.aws_apigatewayv2_stage.default will be created
  + resource "aws_apigatewayv2_stage" "default" {
      + api_id        = (known after apply)
      + arn           = (known after apply)
      + auto_deploy   = true
      + deployment_id = (known after apply)
      + execution_arn = (known after apply)
      + id            = (known after apply)
      + invoke_url    = (known after apply)
      + name          = "$default"
      + region        = "us-east-1"
      + tags_all      = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.compute.aws_cloudwatch_log_group.api will be created
  + resource "aws_cloudwatch_log_group" "api" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/lambda/runracing-demo-api"
      + name_prefix                 = (known after apply)
      + region                      = "us-east-1"
      + retention_in_days           = 14
      + skip_destroy                = false
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.compute.aws_cloudwatch_metric_alarm.api_errors will be created
  + resource "aws_cloudwatch_metric_alarm" "api_errors" {
      + actions_enabled                       = true
      + alarm_description                     = "API Lambda reported function errors"
      + alarm_name                            = "runracing-demo-api-errors"
      + arn                                   = (known after apply)
      + comparison_operator                   = "GreaterThanThreshold"
      + dimensions                            = {
          + "FunctionName" = "runracing-demo-api"
        }
      + evaluate_low_sample_count_percentiles = (known after apply)
      + evaluation_periods                    = 1
      + id                                    = (known after apply)
      + metric_name                           = "Errors"
      + namespace                             = "AWS/Lambda"
      + period                                = 300
      + region                                = "us-east-1"
      + statistic                             = "Sum"
      + tags_all                              = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + threshold                             = 1
      + treat_missing_data                    = "notBreaching"
    }

  # module.compute.aws_iam_role.api will be created
  + resource "aws_iam_role" "api" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "lambda.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "runracing-demo-api-lambda"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.compute.aws_iam_role_policy.api will be created
  + resource "aws_iam_role_policy" "api" {
      + id          = (known after apply)
      + name        = "runracing-demo-api-access"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # module.compute.aws_iam_role_policy_attachment.vpc will be created
  + resource "aws_iam_role_policy_attachment" "vpc" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
      + role       = "runracing-demo-api-lambda"
    }

  # module.compute.aws_lambda_function.api will be created
  + resource "aws_lambda_function" "api" {
      + architectures                  = (known after apply)
      + arn                            = (known after apply)
      + code_sha256                    = (known after apply)
      + filename                       = "../../modules/compute/build/handler.zip"
      + function_name                  = "runracing-demo-api"
      + handler                        = "handler.lambda_handler"
      + id                             = (known after apply)
      + invoke_arn                     = (known after apply)
      + last_modified                  = (known after apply)
      + memory_size                    = 128
      + package_type                   = "Zip"
      + publish                        = false
      + qualified_arn                  = (known after apply)
      + qualified_invoke_arn           = (known after apply)
      + region                         = "us-east-1"
      + reserved_concurrent_executions = -1
      + response_streaming_invoke_arn  = (known after apply)
      + role                           = (known after apply)
      + runtime                        = "python3.12"
      + signing_job_arn                = (known after apply)
      + signing_profile_version_arn    = (known after apply)
      + skip_destroy                   = false
      + source_code_hash               = "mWC+Fu+pfHfSmxx2WC9n4ugxOVM4PePcGJvgYuPi6BM="
      + source_code_size               = (known after apply)
      + tags_all                       = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + timeout                        = 15
      + version                        = (known after apply)

      + environment {
          + variables = (known after apply)
        }

      + ephemeral_storage (known after apply)

      + logging_config (known after apply)

      + tracing_config (known after apply)

      + vpc_config {
          + ipv6_allowed_for_dual_stack = false
          + security_group_ids          = (known after apply)
          + subnet_ids                  = (known after apply)
          + vpc_id                      = (known after apply)
        }
    }

  # module.compute.aws_lambda_permission.apigw will be created
  + resource "aws_lambda_permission" "apigw" {
      + action              = "lambda:InvokeFunction"
      + function_name       = "runracing-demo-api"
      + id                  = (known after apply)
      + principal           = "apigateway.amazonaws.com"
      + region              = "us-east-1"
      + source_arn          = (known after apply)
      + statement_id        = "AllowAPIGatewayInvoke"
      + statement_id_prefix = (known after apply)
    }

  # module.data.data.aws_iam_policy_document.deny_insecure_replays will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "deny_insecure_replays" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:*",
            ]
          + effect    = "Deny"
          + resources = [
              + (known after apply),
              + (known after apply),
            ]
          + sid       = "DenyInsecureTransport"

          + condition {
              + test     = "Bool"
              + values   = [
                  + "false",
                ]
              + variable = "aws:SecureTransport"
            }

          + principals {
              + identifiers = [
                  + "*",
                ]
              + type        = "*"
            }
        }
    }

  # module.data.aws_dynamodb_table.leaderboards will be created
  + resource "aws_dynamodb_table" "leaderboards" {
      + arn              = (known after apply)
      + billing_mode     = "PAY_PER_REQUEST"
      + hash_key         = "leaderboardId"
      + id               = (known after apply)
      + name             = "runracing-demo-leaderboards"
      + range_key        = "playerRef"
      + read_capacity    = (known after apply)
      + region           = "us-east-1"
      + stream_arn       = (known after apply)
      + stream_label     = (known after apply)
      + stream_view_type = (known after apply)
      + tags_all         = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + write_capacity   = (known after apply)

      + attribute {
          + name = "leaderboardId"
          + type = "S"
        }
      + attribute {
          + name = "playerRef"
          + type = "S"
        }

      + global_secondary_index (known after apply)

      + global_table_witness (known after apply)

      + point_in_time_recovery {
          + enabled                 = true
          + recovery_period_in_days = (known after apply)
        }

      + server_side_encryption {
          + enabled     = true
          + kms_key_arn = (known after apply)
        }

      + ttl (known after apply)

      + warm_throughput (known after apply)
    }

  # module.data.aws_dynamodb_table.players will be created
  + resource "aws_dynamodb_table" "players" {
      + arn              = (known after apply)
      + billing_mode     = "PAY_PER_REQUEST"
      + hash_key         = "playerId"
      + id               = (known after apply)
      + name             = "runracing-demo-players"
      + read_capacity    = (known after apply)
      + region           = "us-east-1"
      + stream_arn       = (known after apply)
      + stream_label     = (known after apply)
      + stream_view_type = (known after apply)
      + tags_all         = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + write_capacity   = (known after apply)

      + attribute {
          + name = "playerId"
          + type = "S"
        }

      + global_secondary_index (known after apply)

      + global_table_witness (known after apply)

      + point_in_time_recovery {
          + enabled                 = true
          + recovery_period_in_days = (known after apply)
        }

      + server_side_encryption {
          + enabled     = true
          + kms_key_arn = (known after apply)
        }

      + ttl (known after apply)

      + warm_throughput (known after apply)
    }

  # module.data.aws_elasticache_replication_group.redis will be created
  + resource "aws_elasticache_replication_group" "redis" {
      + apply_immediately              = (known after apply)
      + arn                            = (known after apply)
      + at_rest_encryption_enabled     = "true"
      + auto_minor_version_upgrade     = (known after apply)
      + automatic_failover_enabled     = false
      + cluster_enabled                = (known after apply)
      + cluster_mode                   = (known after apply)
      + configuration_endpoint_address = (known after apply)
      + data_tiering_enabled           = (known after apply)
      + description                    = "Real-time leaderboards (FR-4)"
      + durability                     = (known after apply)
      + engine                         = "redis"
      + engine_version                 = "7.1"
      + engine_version_actual          = (known after apply)
      + global_replication_group_id    = (known after apply)
      + id                             = (known after apply)
      + ip_discovery                   = (known after apply)
      + kms_key_id                     = (known after apply)
      + maintenance_window             = (known after apply)
      + member_clusters                = (known after apply)
      + multi_az_enabled               = false
      + network_type                   = (known after apply)
      + node_type                      = "cache.t4g.micro"
      + num_cache_clusters             = 1
      + num_node_groups                = (known after apply)
      + parameter_group_name           = (known after apply)
      + port                           = 6379
      + primary_endpoint_address       = (known after apply)
      + reader_endpoint_address        = (known after apply)
      + region                         = "us-east-1"
      + replicas_per_node_group        = (known after apply)
      + replication_group_id           = "runracing-demo-redis"
      + security_group_ids             = (known after apply)
      + security_group_names           = (known after apply)
      + snapshot_window                = (known after apply)
      + subnet_group_name              = "runracing-demo-redis"
      + tags_all                       = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + transit_encryption_enabled     = true
      + transit_encryption_mode        = (known after apply)

      + node_group_configuration (known after apply)
    }

  # module.data.aws_elasticache_subnet_group.redis will be created
  + resource "aws_elasticache_subnet_group" "redis" {
      + arn         = (known after apply)
      + description = "Managed by Terraform"
      + id          = (known after apply)
      + name        = "runracing-demo-redis"
      + region      = "us-east-1"
      + subnet_ids  = (known after apply)
      + tags_all    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id      = (known after apply)
    }

  # module.data.aws_s3_bucket.assets will be created
  + resource "aws_s3_bucket" "assets" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "runracing-demo-assets-224848431296"
      + bucket_domain_name          = (known after apply)
      + bucket_namespace            = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_region               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = true
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = "us-east-1"
      + request_payer               = (known after apply)
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + cors_rule (known after apply)

      + grant (known after apply)

      + lifecycle_rule (known after apply)

      + logging (known after apply)

      + object_lock_configuration (known after apply)

      + replication_configuration (known after apply)

      + server_side_encryption_configuration (known after apply)

      + versioning (known after apply)

      + website (known after apply)
    }

  # module.data.aws_s3_bucket.data_lake will be created
  + resource "aws_s3_bucket" "data_lake" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "runracing-demo-data-lake-224848431296"
      + bucket_domain_name          = (known after apply)
      + bucket_namespace            = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_region               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = true
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = "us-east-1"
      + request_payer               = (known after apply)
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + cors_rule (known after apply)

      + grant (known after apply)

      + lifecycle_rule (known after apply)

      + logging (known after apply)

      + object_lock_configuration (known after apply)

      + replication_configuration (known after apply)

      + server_side_encryption_configuration (known after apply)

      + versioning (known after apply)

      + website (known after apply)
    }

  # module.data.aws_s3_bucket.replays will be created
  + resource "aws_s3_bucket" "replays" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "runracing-demo-replays-224848431296"
      + bucket_domain_name          = (known after apply)
      + bucket_namespace            = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_region               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = true
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = "us-east-1"
      + request_payer               = (known after apply)
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + cors_rule (known after apply)

      + grant (known after apply)

      + lifecycle_rule (known after apply)

      + logging (known after apply)

      + object_lock_configuration (known after apply)

      + replication_configuration (known after apply)

      + server_side_encryption_configuration (known after apply)

      + versioning (known after apply)

      + website (known after apply)
    }

  # module.data.aws_s3_bucket_lifecycle_configuration.replays will be created
  + resource "aws_s3_bucket_lifecycle_configuration" "replays" {
      + bucket                                 = (known after apply)
      + expected_bucket_owner                  = (known after apply)
      + id                                     = (known after apply)
      + region                                 = "us-east-1"
      + transition_default_minimum_object_size = "all_storage_classes_128K"

      + rule {
          + id     = "expire-replays"
          + status = "Enabled"
            # (1 unchanged attribute hidden)

          + expiration {
              + days                         = 30
              + expired_object_delete_marker = false
            }

          + filter {
                # (1 unchanged attribute hidden)
            }

          + noncurrent_version_expiration {
              + noncurrent_days = 1
            }
        }
    }

  # module.data.aws_s3_bucket_policy.replays_tls will be created
  + resource "aws_s3_bucket_policy" "replays_tls" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + policy = (known after apply)
      + region = "us-east-1"
    }

  # module.data.aws_s3_bucket_public_access_block.assets will be created
  + resource "aws_s3_bucket_public_access_block" "assets" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + region                  = "us-east-1"
      + restrict_public_buckets = true
    }

  # module.data.aws_s3_bucket_public_access_block.data_lake will be created
  + resource "aws_s3_bucket_public_access_block" "data_lake" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + region                  = "us-east-1"
      + restrict_public_buckets = true
    }

  # module.data.aws_s3_bucket_public_access_block.replays will be created
  + resource "aws_s3_bucket_public_access_block" "replays" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + region                  = "us-east-1"
      + restrict_public_buckets = true
    }

  # module.data.aws_s3_bucket_server_side_encryption_configuration.assets will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + region = "us-east-1"

      + rule {
          + blocked_encryption_types = (known after apply)
          + bucket_key_enabled       = (known after apply)

          + apply_server_side_encryption_by_default {
              + kms_master_key_id = (known after apply)
              + sse_algorithm     = "AES256"
            }
        }
    }

  # module.data.aws_s3_bucket_server_side_encryption_configuration.data_lake will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + region = "us-east-1"

      + rule {
          + blocked_encryption_types = (known after apply)
          + bucket_key_enabled       = true

          + apply_server_side_encryption_by_default {
              + kms_master_key_id = (known after apply)
              + sse_algorithm     = "aws:kms"
            }
        }
    }

  # module.data.aws_s3_bucket_server_side_encryption_configuration.replays will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "replays" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + region = "us-east-1"

      + rule {
          + blocked_encryption_types = (known after apply)
          + bucket_key_enabled       = true

          + apply_server_side_encryption_by_default {
              + kms_master_key_id = (known after apply)
              + sse_algorithm     = "aws:kms"
            }
        }
    }

  # module.data.aws_s3_bucket_versioning.replays will be created
  + resource "aws_s3_bucket_versioning" "replays" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + region = "us-east-1"

      + versioning_configuration {
          + mfa_delete = (known after apply)
          + status     = "Enabled"
        }
    }

  # module.edge.data.aws_iam_policy_document.assets_oac will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "assets_oac" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:GetObject",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "AllowCloudFrontRead"

          + condition {
              + test     = "StringEquals"
              + values   = [
                  + (known after apply),
                ]
              + variable = "AWS:SourceArn"
            }

          + principals {
              + identifiers = [
                  + "cloudfront.amazonaws.com",
                ]
              + type        = "Service"
            }
        }
    }

  # module.edge.aws_cloudfront_distribution.assets will be created
  + resource "aws_cloudfront_distribution" "assets" {
      + arn                             = (known after apply)
      + caller_reference                = (known after apply)
      + comment                         = "runracing-demo assets/replays CDN"
      + continuous_deployment_policy_id = (known after apply)
      + domain_name                     = (known after apply)
      + enabled                         = true
      + etag                            = (known after apply)
      + hosted_zone_id                  = (known after apply)
      + http_version                    = "http2"
      + id                              = (known after apply)
      + in_progress_validation_batches  = (known after apply)
      + is_ipv6_enabled                 = true
      + last_modified_time              = (known after apply)
      + logging_v1_enabled              = (known after apply)
      + price_class                     = "PriceClass_100"
      + retain_on_delete                = false
      + staging                         = false
      + status                          = (known after apply)
      + tags_all                        = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + trusted_key_groups              = (known after apply)
      + trusted_signers                 = (known after apply)
      + wait_for_deployment             = true
      + web_acl_id                      = (known after apply)

      + default_cache_behavior {
          + allowed_methods        = [
              + "GET",
              + "HEAD",
            ]
          + cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
          + cached_methods         = [
              + "GET",
              + "HEAD",
            ]
          + compress               = false
          + default_ttl            = (known after apply)
          + max_ttl                = (known after apply)
          + min_ttl                = 0
          + target_origin_id       = "assets-s3"
          + trusted_key_groups     = (known after apply)
          + trusted_signers        = (known after apply)
          + viewer_protocol_policy = "redirect-to-https"

          + grpc_config (known after apply)
        }

      + origin {
          + connection_attempts         = 3
          + connection_timeout          = 10
          + domain_name                 = (known after apply)
          + origin_access_control_id    = (known after apply)
          + origin_id                   = "assets-s3"
          + response_completion_timeout = (known after apply)
            # (1 unchanged attribute hidden)
        }

      + restrictions {
          + geo_restriction {
              + locations        = (known after apply)
              + restriction_type = "none"
            }
        }

      + viewer_certificate {
          + cloudfront_default_certificate = true
          + minimum_protocol_version       = "TLSv1"
        }
    }

  # module.edge.aws_cloudfront_origin_access_control.assets will be created
  + resource "aws_cloudfront_origin_access_control" "assets" {
      + arn                               = (known after apply)
      + description                       = "Managed by Terraform"
      + etag                              = (known after apply)
      + id                                = (known after apply)
      + name                              = "runracing-demo-assets-oac"
      + origin_access_control_origin_type = "s3"
      + signing_behavior                  = "always"
      + signing_protocol                  = "sigv4"
    }

  # module.edge.aws_s3_bucket_policy.assets_oac will be created
  + resource "aws_s3_bucket_policy" "assets_oac" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + policy = (known after apply)
      + region = "us-east-1"
    }

  # module.edge.aws_wafv2_web_acl.main will be created
  + resource "aws_wafv2_web_acl" "main" {
      + application_integration_url = (known after apply)
      + arn                         = (known after apply)
      + capacity                    = (known after apply)
      + description                 = "Edge protection for the CloudFront distribution"
      + id                          = (known after apply)
      + lock_token                  = (known after apply)
      + name                        = "runracing-demo-cf"
      + name_prefix                 = (known after apply)
      + region                      = "us-east-1"
      + scope                       = "CLOUDFRONT"
      + tags_all                    = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + default_action {
          + allow {
            }
        }

      + rule {
          + name     = "RateLimit"
          + priority = 2

          + action {
              + block {
                }
            }

          + statement {
              + rate_based_statement {
                  + aggregate_key_type    = "IP"
                  + evaluation_window_sec = 300
                  + limit                 = 2000
                }
            }

          + visibility_config {
              + cloudwatch_metrics_enabled = true
              + metric_name                = "runracing-demo-ratelimit"
              + sampled_requests_enabled   = true
            }
        }
      + rule {
          + name     = "AWSCommon"
          + priority = 1

          + override_action {
              + none {}
            }

          + statement {
              + managed_rule_group_statement {
                  + name        = "AWSManagedRulesCommonRuleSet"
                  + vendor_name = "AWS"
                    # (1 unchanged attribute hidden)
                }
            }

          + visibility_config {
              + cloudwatch_metrics_enabled = true
              + metric_name                = "runracing-demo-common"
              + sampled_requests_enabled   = true
            }
        }

      + visibility_config {
          + cloudwatch_metrics_enabled = true
          + metric_name                = "runracing-demo-cf"
          + sampled_requests_enabled   = true
        }
    }

  # module.networking.aws_eip.nat will be created
  + resource "aws_eip" "nat" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + ipam_pool_id         = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + region               = "us-east-1"
      + tags                 = {
          + "Name" = "runracing-demo-nat-eip"
        }
      + tags_all             = {
          + "Name"       = "runracing-demo-nat-eip"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.networking.aws_internet_gateway.main will be created
  + resource "aws_internet_gateway" "main" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + region   = "us-east-1"
      + tags     = {
          + "Name" = "runracing-demo-igw"
        }
      + tags_all = {
          + "Name"       = "runracing-demo-igw"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id   = (known after apply)
    }

  # module.networking.aws_nat_gateway.main will be created
  + resource "aws_nat_gateway" "main" {
      + allocation_id                      = (known after apply)
      + association_id                     = (known after apply)
      + auto_provision_zones               = (known after apply)
      + auto_scaling_ips                   = (known after apply)
      + availability_mode                  = (known after apply)
      + connectivity_type                  = "public"
      + id                                 = (known after apply)
      + network_interface_id               = (known after apply)
      + private_ip                         = (known after apply)
      + public_ip                          = (known after apply)
      + region                             = "us-east-1"
      + regional_nat_gateway_address       = (known after apply)
      + regional_nat_gateway_auto_mode     = (known after apply)
      + route_table_id                     = (known after apply)
      + secondary_allocation_ids           = (known after apply)
      + secondary_private_ip_address_count = (known after apply)
      + secondary_private_ip_addresses     = (known after apply)
      + subnet_id                          = (known after apply)
      + tags                               = {
          + "Name" = "runracing-demo-nat"
        }
      + tags_all                           = {
          + "Name"       = "runracing-demo-nat"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id                             = (known after apply)
    }

  # module.networking.aws_route_table.private will be created
  + resource "aws_route_table" "private" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-east-1"
      + route            = [
          + {
              + cidr_block                 = "0.0.0.0/0"
              + nat_gateway_id             = (known after apply)
                # (12 unchanged attributes hidden)
            },
        ]
      + tags             = {
          + "Name" = "runracing-demo-private-rt"
        }
      + tags_all         = {
          + "Name"       = "runracing-demo-private-rt"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id           = (known after apply)
    }

  # module.networking.aws_route_table.public will be created
  + resource "aws_route_table" "public" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-east-1"
      + route            = [
          + {
              + cidr_block                 = "0.0.0.0/0"
              + gateway_id                 = (known after apply)
                # (12 unchanged attributes hidden)
            },
        ]
      + tags             = {
          + "Name" = "runracing-demo-public-rt"
        }
      + tags_all         = {
          + "Name"       = "runracing-demo-public-rt"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id           = (known after apply)
    }

  # module.networking.aws_route_table_association.private[0] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-east-1"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.networking.aws_route_table_association.private[1] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-east-1"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.networking.aws_route_table_association.public[0] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-east-1"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.networking.aws_route_table_association.public[1] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-east-1"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.networking.aws_security_group.elasticache will be created
  + resource "aws_security_group" "elasticache" {
      + arn                    = (known after apply)
      + description            = "ElastiCache Redis - reachable only from Lambda SG"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
                # (1 unchanged attribute hidden)
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = []
              + description      = "Redis from Lambda"
              + from_port        = 6379
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = (known after apply)
              + self             = false
              + to_port          = 6379
            },
        ]
      + name                   = "runracing-demo-elasticache-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-east-1"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "runracing-demo-elasticache-sg"
        }
      + tags_all               = {
          + "Name"       = "runracing-demo-elasticache-sg"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id                 = (known after apply)
    }

  # module.networking.aws_security_group.lambda will be created
  + resource "aws_security_group" "lambda" {
      + arn                    = (known after apply)
      + description            = "Lambda functions in private subnets"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "All egress"
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = "runracing-demo-lambda-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-east-1"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "runracing-demo-lambda-sg"
        }
      + tags_all               = {
          + "Name"       = "runracing-demo-lambda-sg"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_id                 = (known after apply)
    }

  # module.networking.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.20.10.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-east-1"
      + tags                                           = {
          + "Name" = "runracing-demo-private-0"
          + "tier" = "private"
        }
      + tags_all                                       = {
          + "Name"       = "runracing-demo-private-0"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
          + "tier"       = "private"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.networking.aws_subnet.private[1] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.20.11.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-east-1"
      + tags                                           = {
          + "Name" = "runracing-demo-private-1"
          + "tier" = "private"
        }
      + tags_all                                       = {
          + "Name"       = "runracing-demo-private-1"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
          + "tier"       = "private"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.networking.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.20.0.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-east-1"
      + tags                                           = {
          + "Name" = "runracing-demo-public-0"
          + "tier" = "public"
        }
      + tags_all                                       = {
          + "Name"       = "runracing-demo-public-0"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
          + "tier"       = "public"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.networking.aws_subnet.public[1] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.20.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-east-1"
      + tags                                           = {
          + "Name" = "runracing-demo-public-1"
          + "tier" = "public"
        }
      + tags_all                                       = {
          + "Name"       = "runracing-demo-public-1"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
          + "tier"       = "public"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.networking.aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.20.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + region                               = "us-east-1"
      + tags                                 = {
          + "Name" = "runracing-demo-vpc"
        }
      + tags_all                             = {
          + "Name"       = "runracing-demo-vpc"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.networking.aws_vpc_endpoint.dynamodb will be created
  + resource "aws_vpc_endpoint" "dynamodb" {
      + arn                   = (known after apply)
      + cidr_blocks           = (known after apply)
      + dns_entry             = (known after apply)
      + id                    = (known after apply)
      + ip_address_type       = (known after apply)
      + network_interface_ids = (known after apply)
      + owner_id              = (known after apply)
      + policy                = (known after apply)
      + prefix_list_id        = (known after apply)
      + private_dns_enabled   = (known after apply)
      + region                = "us-east-1"
      + requester_managed     = (known after apply)
      + route_table_ids       = (known after apply)
      + security_group_ids    = (known after apply)
      + service_name          = "com.amazonaws.us-east-1.dynamodb"
      + service_region        = (known after apply)
      + state                 = (known after apply)
      + subnet_ids            = (known after apply)
      + tags                  = {
          + "Name" = "runracing-demo-vpce-dynamodb"
        }
      + tags_all              = {
          + "Name"       = "runracing-demo-vpce-dynamodb"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_endpoint_type     = "Gateway"
      + vpc_id                = (known after apply)

      + dns_options (known after apply)

      + subnet_configuration (known after apply)
    }

  # module.networking.aws_vpc_endpoint.s3 will be created
  + resource "aws_vpc_endpoint" "s3" {
      + arn                   = (known after apply)
      + cidr_blocks           = (known after apply)
      + dns_entry             = (known after apply)
      + id                    = (known after apply)
      + ip_address_type       = (known after apply)
      + network_interface_ids = (known after apply)
      + owner_id              = (known after apply)
      + policy                = (known after apply)
      + prefix_list_id        = (known after apply)
      + private_dns_enabled   = (known after apply)
      + region                = "us-east-1"
      + requester_managed     = (known after apply)
      + route_table_ids       = (known after apply)
      + security_group_ids    = (known after apply)
      + service_name          = "com.amazonaws.us-east-1.s3"
      + service_region        = (known after apply)
      + state                 = (known after apply)
      + subnet_ids            = (known after apply)
      + tags                  = {
          + "Name" = "runracing-demo-vpce-s3"
        }
      + tags_all              = {
          + "Name"       = "runracing-demo-vpce-s3"
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
      + vpc_endpoint_type     = "Gateway"
      + vpc_id                = (known after apply)

      + dns_options (known after apply)

      + subnet_configuration (known after apply)
    }

  # module.security.aws_kms_alias.main will be created
  + resource "aws_kms_alias" "main" {
      + arn            = (known after apply)
      + id             = (known after apply)
      + name           = "alias/runracing-demo"
      + name_prefix    = (known after apply)
      + region         = "us-east-1"
      + target_key_arn = (known after apply)
      + target_key_id  = (known after apply)
    }

  # module.security.aws_kms_key.main will be created
  + resource "aws_kms_key" "main" {
      + arn                                = (known after apply)
      + bypass_policy_lockout_safety_check = false
      + customer_master_key_spec           = "SYMMETRIC_DEFAULT"
      + deletion_window_in_days            = 7
      + description                        = "runracing-demo data encryption key"
      + enable_key_rotation                = true
      + id                                 = (known after apply)
      + is_enabled                         = true
      + key_id                             = (known after apply)
      + key_usage                          = "ENCRYPT_DECRYPT"
      + multi_region                       = (known after apply)
      + policy                             = (known after apply)
      + region                             = "us-east-1"
      + rotation_period_in_days            = (known after apply)
      + tags_all                           = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }
    }

  # module.security.aws_secretsmanager_secret.payment will be created
  + resource "aws_secretsmanager_secret" "payment" {
      + arn                            = (known after apply)
      + description                    = "Payment provider (Stripe) credentials - placeholder for the demo"
      + force_overwrite_replica_secret = false
      + id                             = (known after apply)
      + kms_key_id                     = (known after apply)
      + name                           = "runracing-demo-payment"
      + name_prefix                    = (known after apply)
      + policy                         = (known after apply)
      + recovery_window_in_days        = 0
      + region                         = "us-east-1"
      + tags_all                       = {
          + "env"        = "demo"
          + "managed_by" = "terraform"
          + "project"    = "runracing"
        }

      + replica (known after apply)
    }

  # module.security.aws_secretsmanager_secret_version.payment will be created
  + resource "aws_secretsmanager_secret_version" "payment" {
      + arn                  = (known after apply)
      + has_secret_string_wo = (known after apply)
      + id                   = (known after apply)
      + region               = "us-east-1"
      + secret_arn           = (known after apply)
      + secret_id            = (known after apply)
      + secret_string        = (sensitive value)
      + secret_string_wo     = (write-only attribute)
      + version_id           = (known after apply)
      + version_stages       = (known after apply)
    }

Plan: 70 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_health_url         = (known after apply)
  + assets_bucket          = (known after apply)
  + athena_workgroup       = "runracing-demo"
  + cloudfront_domain      = (known after apply)
  + consumer_function      = "runracing-demo-consumer"
  + data_lake_bucket       = (known after apply)
  + glue_database          = "runracing_demo_analytics"
  + leaderboards_table     = "runracing-demo-leaderboards"
  + players_table          = "runracing-demo-players"
  + redis_primary_endpoint = (known after apply)
  + replays_bucket         = (known after apply)
  + telemetry_stream       = "runracing-demo-telemetry"

─────────────────────────────────────────────────────────────────────────────

Saved the plan to: tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"
Releasing state lock. This may take a few moments...
PLAN_EXIT=0
```

---

## Step 4 — Apply (70 resources created)

```bash
AWS_PROFILE=runracing-deployer terraform apply tfplan
```

```text
module.edge.aws_cloudfront_origin_access_control.assets: Creating...
module.analytics.aws_glue_catalog_database.analytics: Creating...
module.security.aws_kms_key.main: Creating...
module.analytics.aws_iam_role.glue: Creating...
module.analytics.aws_cloudwatch_log_group.firehose: Creating...
module.compute.aws_iam_role.api: Creating...
module.compute.aws_cloudwatch_log_group.api: Creating...
module.networking.aws_vpc.main: Creating...
module.analytics.aws_cloudwatch_log_group.consumer: Creating...
module.analytics.aws_iam_role.consumer: Creating...
module.edge.aws_cloudfront_origin_access_control.assets: Creation complete after 1s [id=E2O5ESF1DP161U]
module.networking.aws_eip.nat: Creating...
module.analytics.aws_glue_catalog_database.analytics: Creation complete after 1s [id=224848431296:runracing_demo_analytics]
module.compute.aws_apigatewayv2_api.http: Creating...
module.analytics.aws_cloudwatch_log_group.consumer: Creation complete after 1s [id=/aws/lambda/runracing-demo-consumer]
module.analytics.aws_iam_role.firehose: Creating...
module.analytics.aws_cloudwatch_log_group.firehose: Creation complete after 1s [id=/aws/kinesisfirehose/runracing-demo-to-lake]
module.analytics.aws_iam_role.glue: Creation complete after 1s [id=runracing-demo-glue]
module.data.aws_s3_bucket.data_lake: Creating...
module.analytics.aws_iam_role.consumer: Creation complete after 1s [id=runracing-demo-consumer]
module.data.aws_s3_bucket.replays: Creating...
module.compute.aws_iam_role.api: Creation complete after 1s [id=runracing-demo-api-lambda]
module.data.aws_s3_bucket.assets: Creating...
module.compute.aws_cloudwatch_log_group.api: Creation complete after 5s [id=/aws/lambda/runracing-demo-api]
module.analytics.aws_cloudwatch_log_stream.firehose: Creating...
module.edge.aws_wafv2_web_acl.main: Creating...
module.compute.aws_apigatewayv2_api.http: Creation complete after 5s [id=c7ejbtbh50]
module.analytics.aws_iam_role_policy_attachment.glue_service: Creating...
module.analytics.aws_iam_role.firehose: Creation complete after 5s [id=runracing-demo-firehose]
module.compute.aws_iam_role_policy_attachment.vpc: Creating...
module.analytics.aws_cloudwatch_log_stream.firehose: Creation complete after 1s [id=S3Delivery]
module.compute.aws_apigatewayv2_stage.default: Creating...
module.compute.aws_iam_role_policy_attachment.vpc: Creation complete after 0s [id=runracing-demo-api-lambda/arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole]
module.analytics.aws_iam_role_policy_attachment.glue_service: Creation complete after 0s [id=runracing-demo-glue/arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole]
module.edge.aws_wafv2_web_acl.main: Creation complete after 2s [id=c8425c7d-0c43-47d6-93e8-3a34ed7c41b1]
module.networking.aws_eip.nat: Creation complete after 6s [id=eipalloc-09f47670f0993c39d]
module.compute.aws_apigatewayv2_stage.default: Creation complete after 1s [id=$default]
module.networking.aws_vpc.main: Creation complete after 8s [id=vpc-0ddaa60c5823085eb]
module.networking.aws_internet_gateway.main: Creating...
module.networking.aws_subnet.private[1]: Creating...
module.networking.aws_subnet.public[1]: Creating...
module.networking.aws_subnet.private[0]: Creating...
module.networking.aws_security_group.lambda: Creating...
module.networking.aws_subnet.public[0]: Creating...
module.networking.aws_subnet.private[1]: Creation complete after 2s [id=subnet-05929ae485d6872ec]
module.data.aws_s3_bucket.replays: Creation complete after 9s [id=runracing-demo-replays-224848431296]
module.data.aws_s3_bucket_versioning.replays: Creating...
module.data.aws_s3_bucket_lifecycle_configuration.replays: Creating...
module.networking.aws_subnet.private[0]: Creation complete after 2s [id=subnet-0734c5790b892597a]
module.data.aws_s3_bucket_public_access_block.replays: Creating...
module.networking.aws_internet_gateway.main: Creation complete after 2s [id=igw-0402e54b54f962d3e]
module.data.data.aws_iam_policy_document.deny_insecure_replays: Reading...
module.data.data.aws_iam_policy_document.deny_insecure_replays: Read complete after 0s [id=4217157181]
module.networking.aws_route_table.public: Creating...
module.data.aws_s3_bucket.data_lake: Creation complete after 9s [id=runracing-demo-data-lake-224848431296]
module.data.aws_s3_bucket_policy.replays_tls: Creating...
module.data.aws_s3_bucket.assets: Creation complete after 10s [id=runracing-demo-assets-224848431296]
module.data.aws_s3_bucket_public_access_block.data_lake: Creating...
module.data.aws_s3_bucket_public_access_block.replays: Creation complete after 1s [id=runracing-demo-replays-224848431296]
module.data.aws_s3_bucket_server_side_encryption_configuration.assets: Creating...
module.data.aws_s3_bucket_public_access_block.data_lake: Creation complete after 0s [id=runracing-demo-data-lake-224848431296]
module.data.aws_s3_bucket_public_access_block.assets: Creating...
module.data.aws_s3_bucket_policy.replays_tls: Creation complete after 2s [id=runracing-demo-replays-224848431296]
module.data.aws_elasticache_subnet_group.redis: Creating...
module.data.aws_s3_bucket_versioning.replays: Creation complete after 2s [id=runracing-demo-replays-224848431296]
module.analytics.aws_glue_crawler.telemetry: Creating...
module.data.aws_s3_bucket_server_side_encryption_configuration.assets: Creation complete after 2s [id=runracing-demo-assets-224848431296]
module.edge.aws_cloudfront_distribution.assets: Creating...
module.networking.aws_route_table.public: Creation complete after 3s [id=rtb-0fd192818f5f8a1f3]
module.security.aws_kms_key.main: Still creating... [00m13s elapsed]
module.data.aws_s3_bucket_public_access_block.assets: Creation complete after 2s [id=runracing-demo-assets-224848431296]
module.analytics.aws_glue_crawler.telemetry: Creation complete after 1s [id=runracing-demo-telemetry]
module.data.aws_elasticache_subnet_group.redis: Creation complete after 3s [id=runracing-demo-redis]
module.networking.aws_security_group.lambda: Creation complete after 7s [id=sg-02361f7955f22d440]
module.networking.aws_security_group.elasticache: Creating...
module.security.aws_kms_key.main: Creation complete after 16s [id=83fe7fcf-c058-4273-99da-fd7dffcad4e5]
module.security.aws_kms_alias.main: Creating...
module.security.aws_secretsmanager_secret.payment: Creating...
module.data.aws_s3_bucket_server_side_encryption_configuration.replays: Creating...
module.data.aws_dynamodb_table.players: Creating...
module.analytics.aws_athena_workgroup.main: Creating...
module.security.aws_kms_alias.main: Creation complete after 1s [id=alias/runracing-demo]
module.data.aws_s3_bucket_server_side_encryption_configuration.data_lake: Creating...
module.data.aws_s3_bucket_server_side_encryption_configuration.replays: Creation complete after 1s [id=runracing-demo-replays-224848431296]
module.data.aws_dynamodb_table.leaderboards: Creating...
module.analytics.aws_athena_workgroup.main: Creation complete after 1s [id=runracing-demo]
module.analytics.data.aws_iam_policy_document.glue_lake: Reading...
module.analytics.data.aws_iam_policy_document.glue_lake: Read complete after 0s [id=2209417411]
module.data.aws_s3_bucket_server_side_encryption_configuration.data_lake: Creation complete after 0s [id=runracing-demo-data-lake-224848431296]
module.analytics.aws_iam_role_policy.glue_lake: Creating...
module.security.aws_secretsmanager_secret.payment: Creation complete after 2s [id=arn:aws:secretsmanager:us-east-1:224848431296:secret:runracing-demo-payment-yNxwsV]
module.security.aws_secretsmanager_secret_version.payment: Creating...
module.analytics.aws_iam_role_policy.glue_lake: Creation complete after 1s [id=runracing-demo-glue:runracing-demo-glue-lake]
module.networking.aws_subnet.public[1]: Still creating... [00m10s elapsed]
module.networking.aws_subnet.public[0]: Still creating... [00m10s elapsed]
module.analytics.aws_kinesis_stream.telemetry: Creating...
module.security.aws_secretsmanager_secret_version.payment: Creation complete after 1s [id=arn:aws:secretsmanager:us-east-1:224848431296:secret:runracing-demo-payment-yNxwsV|terraform-Necyc8kk7C88OOohyV2zk0UjUF]
module.networking.aws_security_group.elasticache: Creation complete after 4s [id=sg-00c802aa36b751181]
module.data.aws_elasticache_replication_group.redis: Creating...
module.data.aws_s3_bucket_lifecycle_configuration.replays: Still creating... [00m10s elapsed]
module.networking.aws_subnet.public[0]: Creation complete after 13s [id=subnet-07db96e475eb6feed]
module.networking.aws_nat_gateway.main: Creating...
module.edge.aws_cloudfront_distribution.assets: Still creating... [00m10s elapsed]
module.networking.aws_subnet.public[1]: Creation complete after 16s [id=subnet-075918811f244d7c4]
module.networking.aws_route_table_association.public[1]: Creating...
module.networking.aws_route_table_association.public[0]: Creating...
module.data.aws_dynamodb_table.players: Still creating... [00m10s elapsed]
module.networking.aws_route_table_association.public[0]: Creation complete after 1s [id=rtbassoc-0cc95260d3dfd8962]
module.networking.aws_route_table_association.public[1]: Creation complete after 1s [id=rtbassoc-0de40e48a35eb16c6]
module.data.aws_dynamodb_table.players: Creation complete after 11s [id=runracing-demo-players]
module.data.aws_dynamodb_table.leaderboards: Creation complete after 10s [id=runracing-demo-leaderboards]
module.analytics.aws_kinesis_stream.telemetry: Still creating... [00m10s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [00m10s elapsed]
module.data.aws_s3_bucket_lifecycle_configuration.replays: Still creating... [00m20s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [00m10s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [00m20s elapsed]
module.analytics.aws_kinesis_stream.telemetry: Still creating... [00m23s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [00m23s elapsed]
module.data.aws_s3_bucket_lifecycle_configuration.replays: Still creating... [00m33s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [00m23s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [00m33s elapsed]
module.analytics.aws_kinesis_stream.telemetry: Still creating... [00m33s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [00m33s elapsed]
module.data.aws_s3_bucket_lifecycle_configuration.replays: Still creating... [00m43s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [00m33s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [00m43s elapsed]
module.analytics.aws_kinesis_stream.telemetry: Creation complete after 38s [id=arn:aws:kinesis:us-east-1:224848431296:stream/runracing-demo-telemetry]
module.analytics.data.aws_iam_policy_document.consumer: Reading...
module.analytics.data.aws_iam_policy_document.firehose: Reading...
module.compute.data.aws_iam_policy_document.api: Reading...
module.analytics.data.aws_iam_policy_document.consumer: Read complete after 0s [id=1952157203]
module.analytics.data.aws_iam_policy_document.firehose: Read complete after 0s [id=3108505763]
module.compute.data.aws_iam_policy_document.api: Read complete after 0s [id=1692361073]
module.analytics.aws_iam_role_policy.consumer: Creating...
module.analytics.aws_iam_role_policy.firehose: Creating...
module.compute.aws_iam_role_policy.api: Creating...
module.analytics.aws_iam_role_policy.firehose: Creation complete after 0s [id=runracing-demo-firehose:runracing-demo-firehose-access]
module.analytics.aws_iam_role_policy.consumer: Creation complete after 0s [id=runracing-demo-consumer:runracing-demo-consumer-access]
module.analytics.aws_lambda_function.consumer: Creating...
module.analytics.aws_kinesis_firehose_delivery_stream.to_lake: Creating...
module.compute.aws_iam_role_policy.api: Creation complete after 0s [id=runracing-demo-api-lambda:runracing-demo-api-access]
module.data.aws_elasticache_replication_group.redis: Still creating... [00m43s elapsed]
module.data.aws_s3_bucket_lifecycle_configuration.replays: Still creating... [00m53s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [00m43s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [00m53s elapsed]
module.analytics.aws_lambda_function.consumer: Creation complete after 8s [id=runracing-demo-consumer]
module.analytics.aws_lambda_event_source_mapping.consumer: Creating...
module.analytics.aws_kinesis_firehose_delivery_stream.to_lake: Creation complete after 9s [id=arn:aws:firehose:us-east-1:224848431296:deliverystream/runracing-demo-to-lake]
module.analytics.aws_lambda_event_source_mapping.consumer: Creation complete after 2s [id=5853415d-bc91-4e80-a47c-70d7f0972162]
module.data.aws_s3_bucket_lifecycle_configuration.replays: Creation complete after 1m2s [id=runracing-demo-replays-224848431296]
module.data.aws_elasticache_replication_group.redis: Still creating... [00m57s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [00m56s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m06s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [01m07s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [01m06s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m16s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [01m17s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [01m16s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m26s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [01m27s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [01m26s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m39s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [01m40s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [01m39s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m49s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [01m50s elapsed]
module.networking.aws_nat_gateway.main: Still creating... [01m49s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [01m59s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m00s elapsed]
module.networking.aws_nat_gateway.main: Creation complete after 1m58s [id=nat-0f148d5d8d843e577]
module.networking.aws_route_table.private: Creating...
module.edge.aws_cloudfront_distribution.assets: Still creating... [02m09s elapsed]
module.networking.aws_route_table.private: Creation complete after 5s [id=rtb-0c73fa78b746427c3]
module.networking.aws_route_table_association.private[1]: Creating...
module.networking.aws_route_table_association.private[0]: Creating...
module.networking.aws_vpc_endpoint.s3: Creating...
module.networking.aws_vpc_endpoint.dynamodb: Creating...
module.networking.aws_route_table_association.private[1]: Creation complete after 2s [id=rtbassoc-034b85b373602fc88]
module.networking.aws_route_table_association.private[0]: Creation complete after 2s [id=rtbassoc-06918ce2b3517b26b]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m13s elapsed]
module.networking.aws_vpc_endpoint.s3: Creation complete after 8s [id=vpce-012d88696480cc949]
module.networking.aws_vpc_endpoint.dynamodb: Creation complete after 9s [id=vpce-0524275df90f93682]
module.edge.aws_cloudfront_distribution.assets: Still creating... [02m22s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m23s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [02m32s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m33s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [02m42s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m46s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [02m55s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [02m56s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [03m05s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [03m06s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [03m15s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [03m20s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [03m29s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [03m30s elapsed]
module.edge.aws_cloudfront_distribution.assets: Still creating... [03m39s elapsed]
module.edge.aws_cloudfront_distribution.assets: Creation complete after 3m45s [id=E2JBX6FY4LXUQM]
module.data.aws_elasticache_replication_group.redis: Still creating... [03m40s elapsed]
module.edge.data.aws_iam_policy_document.assets_oac: Reading...
module.edge.data.aws_iam_policy_document.assets_oac: Read complete after 0s [id=237773889]
module.edge.aws_s3_bucket_policy.assets_oac: Creating...
module.edge.aws_s3_bucket_policy.assets_oac: Creation complete after 2s [id=runracing-demo-assets-224848431296]
module.data.aws_elasticache_replication_group.redis: Still creating... [03m50s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [04m03s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [04m13s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [04m23s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [04m36s elapsed]
module.data.aws_elasticache_replication_group.redis: Still creating... [04m46s elapsed]
module.data.aws_elasticache_replication_group.redis: Creation complete after 4m47s [id=runracing-demo-redis]
module.compute.aws_lambda_function.api: Creating...
module.compute.aws_lambda_function.api: Still creating... [00m10s elapsed]
module.compute.aws_lambda_function.api: Still creating... [00m23s elapsed]
module.compute.aws_lambda_function.api: Still creating... [00m33s elapsed]
module.compute.aws_lambda_function.api: Still creating... [00m43s elapsed]
module.compute.aws_lambda_function.api: Still creating... [00m57s elapsed]
module.compute.aws_lambda_function.api: Still creating... [01m07s elapsed]
module.compute.aws_lambda_function.api: Still creating... [01m17s elapsed]
module.compute.aws_lambda_function.api: Still creating... [01m30s elapsed]
module.compute.aws_lambda_function.api: Still creating... [01m40s elapsed]
module.compute.aws_lambda_function.api: Still creating... [01m50s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m03s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m13s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m23s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m33s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m46s elapsed]
module.compute.aws_lambda_function.api: Still creating... [02m56s elapsed]
module.compute.aws_lambda_function.api: Still creating... [03m06s elapsed]
module.compute.aws_lambda_function.api: Still creating... [03m20s elapsed]
module.compute.aws_lambda_function.api: Still creating... [03m30s elapsed]
module.compute.aws_lambda_function.api: Still creating... [03m40s elapsed]
module.compute.aws_lambda_function.api: Creation complete after 3m52s [id=runracing-demo-api]
module.compute.aws_lambda_permission.apigw: Creating...
module.compute.aws_apigatewayv2_integration.lambda: Creating...
module.compute.aws_cloudwatch_metric_alarm.api_errors: Creating...
module.compute.aws_lambda_permission.apigw: Creation complete after 1s [id=AllowAPIGatewayInvoke]
module.compute.aws_apigatewayv2_integration.lambda: Creation complete after 1s [id=lc0w78e]
module.compute.aws_apigatewayv2_route.health: Creating...
module.compute.aws_cloudwatch_metric_alarm.api_errors: Creation complete after 2s [id=runracing-demo-api-errors]
module.compute.aws_apigatewayv2_route.health: Creation complete after 1s [id=gswl99i]
Releasing state lock. This may take a few moments...

Apply complete! Resources: 70 added, 0 changed, 0 destroyed.

Outputs:

api_health_url = "https://c7ejbtbh50.execute-api.us-east-1.amazonaws.com/health"
assets_bucket = "runracing-demo-assets-224848431296"
athena_workgroup = "runracing-demo"
cloudfront_domain = "dmuz9eerzslob.cloudfront.net"
consumer_function = "runracing-demo-consumer"
data_lake_bucket = "runracing-demo-data-lake-224848431296"
glue_database = "runracing_demo_analytics"
leaderboards_table = "runracing-demo-leaderboards"
players_table = "runracing-demo-players"
redis_primary_endpoint = "master.runracing-demo-redis.w7zzq6.use1.cache.amazonaws.com"
replays_bucket = "runracing-demo-replays-224848431296"
telemetry_stream = "runracing-demo-telemetry"
APPLY_EXIT=0
```

---

## Step 5 — Validation (endpoint, storage, streaming, security, edge)

```bash
cd demo/terraform/envs/demo
export AWS_PROFILE=runracing-deployer AWS_REGION=us-east-1
HURL=$(terraform output -raw api_health_url)
CFD=$(terraform output -raw cloudfront_domain)

echo "################ VALIDATION ################"

# 0. Deploy identity (must be the scoped deployer, not root)
echo "=== 0. Deploy identity (scoped deployer, not root) ==="; aws sts get-caller-identity --output table

# 1. Endpoint availability + end-to-end storage/streaming/secrets checks
echo; echo "=== 1. ENDPOINT: GET $HURL ==="; curl -s -S -w "\nHTTP_STATUS=%{http_code}\n" "$HURL"

# 2. Storage access (items written by the Lambda)
echo; echo "=== 2. STORAGE: DynamoDB item (written by Lambda) ==="; aws dynamodb scan --table-name runracing-demo-players --max-items 3 --output json

echo; echo "=== 2b. STORAGE: S3 replay object ==="; aws s3 ls s3://runracing-demo-replays-224848431296/healthcheck/ --recursive

echo; echo "=== 2c. STREAMING: Kinesis stream status + consumer ESM ==="
aws kinesis describe-stream-summary --stream-name runracing-demo-telemetry --query 'StreamDescriptionSummary.{Name:StreamName,Status:StreamStatus,Encryption:EncryptionType}' --output json
aws lambda list-event-source-mappings --function-name runracing-demo-consumer --query 'EventSourceMappings[].{State:State,Source:EventSourceArn}' --output json

# 3. Security posture
echo; echo "=== 3. SECURITY: S3 replays encryption (KMS) + public access block ==="
aws s3api get-bucket-encryption --bucket runracing-demo-replays-224848431296 --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault' --output json
aws s3api get-public-access-block --bucket runracing-demo-replays-224848431296 --query 'PublicAccessBlockConfiguration' --output json
echo "--- assets bucket encryption (SSE-S3 for CloudFront OAC) ---"
aws s3api get-bucket-encryption --bucket runracing-demo-assets-224848431296 --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault' --output json

echo; echo "=== 3b. SECURITY: DynamoDB SSE (CMK) ==="; aws dynamodb describe-table --table-name runracing-demo-players --query 'Table.SSEDescription' --output json

echo; echo "=== 3c. SECURITY: ElastiCache encryption (at-rest + in-transit) ==="
aws elasticache describe-replication-groups --replication-group-id runracing-demo-redis --query 'ReplicationGroups[0].{AtRest:AtRestEncryptionEnabled,InTransit:TransitEncryptionEnabled,Status:Status}' --output json

echo; echo "=== 3d. SECURITY: WAFv2 (CLOUDFRONT) web ACL ==="
aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 --query "WebACLs[?starts_with(Name,'runracing')].{Name:Name,Id:Id}" --output json

echo; echo "=== 3e. SECURITY: Secrets Manager (KMS-encrypted) ==="
aws secretsmanager describe-secret --secret-id runracing-demo-payment --query '{Name:Name,KmsKeyId:KmsKeyId}' --output json

# 4. Edge: CloudFront responds over TLS
echo; echo "=== 4. EDGE: CloudFront responds over TLS (https://$CFD) ==="
curl -s -o /dev/null -w "cloudfront HTTP_STATUS=%{http_code}\n" "https://$CFD/" || true
echo "################ END VALIDATION ################"
echo "VALIDATION done"
```

```text
################ VALIDATION ################
=== 0. Deploy identity (scoped deployer, not root) ===
------------------------------------------------------------------
|                        GetCallerIdentity                       |
+---------+------------------------------------------------------+
|  Account|  224848431296                                        |
|  Arn    |  arn:aws:iam::224848431296:user/runracing-deployer   |
|  UserId |  AIDATIWQCZDAGQQNWHZHU                               |
+---------+------------------------------------------------------+

=== 1. ENDPOINT: GET https://c7ejbtbh50.execute-api.us-east-1.amazonaws.com/health ===
{"status": "ok", "service": "runracing-demo-api", "region": "us-east-1", "checks": {"dynamodb": "ok", "s3": "ok", "kinesis": "ok", "secrets": "ok", "redis_endpoint_configured": "yes"}}
HTTP_STATUS=200

=== 2. STORAGE: DynamoDB item (written by Lambda) ===
{
    "Items": [
        {
            "note": {
                "S": "demo health check"
            },
            "playerId": {
                "S": "healthcheck-1782373248"
            }
        }
    ],
    "Count": 1,
    "ScannedCount": 1,
    "ConsumedCapacity": null
}

=== 2b. STORAGE: S3 replay object ===
2026-06-25 15:40:49         17 healthcheck/check.txt

=== 2c. STREAMING: Kinesis stream status + consumer ESM ===
{
    "Name": "runracing-demo-telemetry",
    "Status": "ACTIVE",
    "Encryption": "KMS"
}
[
    {
        "State": "Enabled",
        "Source": "arn:aws:kinesis:us-east-1:224848431296:stream/runracing-demo-telemetry"
    }
]

=== 3. SECURITY: S3 replays encryption (KMS) + public access block ===
{
    "SSEAlgorithm": "aws:kms",
    "KMSMasterKeyID": "arn:aws:kms:us-east-1:224848431296:key/83fe7fcf-c058-4273-99da-fd7dffcad4e5"
}
{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}
--- assets bucket encryption (SSE-S3 for CloudFront OAC) ---
{
    "SSEAlgorithm": "AES256"
}

=== 3b. SECURITY: DynamoDB SSE (CMK) ===
{
    "Status": "ENABLED",
    "SSEType": "KMS",
    "KMSMasterKeyArn": "arn:aws:kms:us-east-1:224848431296:key/83fe7fcf-c058-4273-99da-fd7dffcad4e5"
}

=== 3c. SECURITY: ElastiCache encryption (at-rest + in-transit) ===
{
    "AtRest": true,
    "InTransit": true,
    "Status": "available"
}

=== 3d. SECURITY: WAFv2 (CLOUDFRONT) web ACL ===
[
    {
        "Name": "runracing-demo-cf",
        "Id": "c8425c7d-0c43-47d6-93e8-3a34ed7c41b1"
    }
]

=== 3e. SECURITY: Secrets Manager (KMS-encrypted) ===
{
    "Name": "runracing-demo-payment",
    "KmsKeyId": "arn:aws:kms:us-east-1:224848431296:key/83fe7fcf-c058-4273-99da-fd7dffcad4e5"
}

=== 4. EDGE: CloudFront responds over TLS (https://dmuz9eerzslob.cloudfront.net) ===
cloudfront HTTP_STATUS=403
################ END VALIDATION ################
VALIDATION done
```

---

## Step 6 — Resource inventory

```bash
AWS_PROFILE=runracing-deployer terraform state list
AWS_PROFILE=runracing-deployer terraform output
```

```text
################ RESOURCE INVENTORY ################
=== terraform state list ===
data.aws_caller_identity.current
module.analytics.data.archive_file.consumer
module.analytics.data.aws_iam_policy_document.consumer
module.analytics.data.aws_iam_policy_document.consumer_assume
module.analytics.data.aws_iam_policy_document.firehose
module.analytics.data.aws_iam_policy_document.firehose_assume
module.analytics.data.aws_iam_policy_document.glue_assume
module.analytics.data.aws_iam_policy_document.glue_lake
module.analytics.aws_athena_workgroup.main
module.analytics.aws_cloudwatch_log_group.consumer
module.analytics.aws_cloudwatch_log_group.firehose
module.analytics.aws_cloudwatch_log_stream.firehose
module.analytics.aws_glue_catalog_database.analytics
module.analytics.aws_glue_crawler.telemetry
module.analytics.aws_iam_role.consumer
module.analytics.aws_iam_role.firehose
module.analytics.aws_iam_role.glue
module.analytics.aws_iam_role_policy.consumer
module.analytics.aws_iam_role_policy.firehose
module.analytics.aws_iam_role_policy.glue_lake
module.analytics.aws_iam_role_policy_attachment.glue_service
module.analytics.aws_kinesis_firehose_delivery_stream.to_lake
module.analytics.aws_kinesis_stream.telemetry
module.analytics.aws_lambda_event_source_mapping.consumer
module.analytics.aws_lambda_function.consumer
module.compute.data.archive_file.lambda
module.compute.data.aws_iam_policy_document.api
module.compute.data.aws_iam_policy_document.assume
module.compute.aws_apigatewayv2_api.http
module.compute.aws_apigatewayv2_integration.lambda
module.compute.aws_apigatewayv2_route.health
module.compute.aws_apigatewayv2_stage.default
module.compute.aws_cloudwatch_log_group.api
module.compute.aws_cloudwatch_metric_alarm.api_errors
module.compute.aws_iam_role.api
module.compute.aws_iam_role_policy.api
module.compute.aws_iam_role_policy_attachment.vpc
module.compute.aws_lambda_function.api
module.compute.aws_lambda_permission.apigw
module.data.data.aws_iam_policy_document.deny_insecure_replays
module.data.aws_dynamodb_table.leaderboards
module.data.aws_dynamodb_table.players
module.data.aws_elasticache_replication_group.redis
module.data.aws_elasticache_subnet_group.redis
module.data.aws_s3_bucket.assets
module.data.aws_s3_bucket.data_lake
module.data.aws_s3_bucket.replays
module.data.aws_s3_bucket_lifecycle_configuration.replays
module.data.aws_s3_bucket_policy.replays_tls
module.data.aws_s3_bucket_public_access_block.assets
module.data.aws_s3_bucket_public_access_block.data_lake
module.data.aws_s3_bucket_public_access_block.replays
module.data.aws_s3_bucket_server_side_encryption_configuration.assets
module.data.aws_s3_bucket_server_side_encryption_configuration.data_lake
module.data.aws_s3_bucket_server_side_encryption_configuration.replays
module.data.aws_s3_bucket_versioning.replays
module.edge.data.aws_iam_policy_document.assets_oac
module.edge.aws_cloudfront_distribution.assets
module.edge.aws_cloudfront_origin_access_control.assets
module.edge.aws_s3_bucket_policy.assets_oac
module.edge.aws_wafv2_web_acl.main
module.networking.data.aws_availability_zones.available
module.networking.aws_eip.nat
module.networking.aws_internet_gateway.main
module.networking.aws_nat_gateway.main
module.networking.aws_route_table.private
module.networking.aws_route_table.public
module.networking.aws_route_table_association.private[0]
module.networking.aws_route_table_association.private[1]
module.networking.aws_route_table_association.public[0]
module.networking.aws_route_table_association.public[1]
module.networking.aws_security_group.elasticache
module.networking.aws_security_group.lambda
module.networking.aws_subnet.private[0]
module.networking.aws_subnet.private[1]
module.networking.aws_subnet.public[0]
module.networking.aws_subnet.public[1]
module.networking.aws_vpc.main
module.networking.aws_vpc_endpoint.dynamodb
module.networking.aws_vpc_endpoint.s3
module.security.aws_kms_alias.main
module.security.aws_kms_key.main
module.security.aws_secretsmanager_secret.payment
module.security.aws_secretsmanager_secret_version.payment

=== resource count ===
84

=== terraform outputs ===
api_health_url = "https://c7ejbtbh50.execute-api.us-east-1.amazonaws.com/health"
assets_bucket = "runracing-demo-assets-224848431296"
athena_workgroup = "runracing-demo"
cloudfront_domain = "dmuz9eerzslob.cloudfront.net"
consumer_function = "runracing-demo-consumer"
data_lake_bucket = "runracing-demo-data-lake-224848431296"
glue_database = "runracing_demo_analytics"
leaderboards_table = "runracing-demo-leaderboards"
players_table = "runracing-demo-players"
redis_primary_endpoint = "master.runracing-demo-redis.w7zzq6.use1.cache.amazonaws.com"
replays_bucket = "runracing-demo-replays-224848431296"
telemetry_stream = "runracing-demo-telemetry"
################ END INVENTORY ################
```

---

## Constraints and omissions

Components represented in the architecture but **not instantiated** in the demo, because
they require external artifacts or subscriptions:

| Component | Reason | Demo treatment |
| --- | --- | --- |
| GameLift fleet + FlexMatch | Needs the Unity dedicated-server build (a game binary) | Designed only (architecture Section 5) |
| Managed Service for Apache Flink | Needs an application JAR artifact | Kinesis **consumer Lambda** performs the real-time path |
| QuickSight dashboards | Needs an account-level QuickSight subscription | Glue + Athena provide the query layer |

Demo-vs-production deltas (cost/scope simplifications):

- Single region (production: active-active multi-region with DynamoDB global tables).
- One NAT gateway (production: one per AZ).
- ElastiCache single node (production: multi-node with automatic failover).
- Assets bucket uses SSE-S3 so CloudFront OAC can read it without a CloudFront-scoped KMS
  key policy; replays, data lake, DynamoDB, Kinesis, and Secrets use the CMK.
- CloudWatch log groups use default encryption (production: CMK with a logs key policy).
- `force_destroy = true` on demo buckets for clean teardown (production: `false`).

See [03-architecture.md](03-architecture.md) Section 19 for the full treatment.

---

## Teardown reference

```bash
cd demo/terraform/envs/demo
AWS_PROFILE=runracing-deployer terraform destroy -auto-approve
```

`force_destroy = true` lets the versioned demo buckets be removed without manual emptying.

End of deployment log.
