output "api_endpoint" {
  description = "Base invoke URL of the HTTP API (append /health)."
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "function_name" {
  description = "Name of the API Lambda function."
  value       = aws_lambda_function.api.function_name
}
