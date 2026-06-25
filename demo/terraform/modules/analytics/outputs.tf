output "telemetry_stream_name" {
  value       = aws_kinesis_stream.telemetry.name
  description = "Kinesis telemetry stream name."
}

output "telemetry_stream_arn" {
  value       = aws_kinesis_stream.telemetry.arn
  description = "Kinesis telemetry stream ARN."
}

output "firehose_name" {
  value       = aws_kinesis_firehose_delivery_stream.to_lake.name
  description = "Firehose delivery stream name."
}

output "glue_database" {
  value       = aws_glue_catalog_database.analytics.name
  description = "Glue catalog database name."
}

output "athena_workgroup" {
  value       = aws_athena_workgroup.main.name
  description = "Athena workgroup name."
}

output "consumer_function_name" {
  value       = aws_lambda_function.consumer.function_name
  description = "Real-time consumer Lambda name."
}
