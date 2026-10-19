output "lambda_arn" {
    description = "Lambda Arn"
    value = {
        arn = aws_lambda_function.calculator.arn
        invoke_arn = aws_lambda_function.calculator.invoke_arn
    }
}

output "api_url" {
    description = "Base URL of the calculator http API"
    value = aws_apigatewayv2_api.calculator.api_endpoint
}

output "lambda_function_name" {
    description = "Name of the deployed calculator function"
    value = aws_lambda_function.calculator.function_name
}