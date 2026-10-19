output "rest_api_id" {
  value = aws_api_gateway_rest_api.users_api.id
}

output "api_url" {
  value = aws_api_gateway_rest_api.users_api
}