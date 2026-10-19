terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = var.region
}

# ------ IAM role for lambda function use ------------------
resource "aws_iam_role" "lambda_role" {
    name = "calculator-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }]
    })
}


# ------- Allow lambda to write execution log to cloudWatch -----------
resource "aws_iam_role_policy_attachment" "lambda_logging" {
    role = aws_iam_role.lambda_role.name

    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Save python file into zip form because lambda use only zip 
data "archive_file" "lambda_zip" {
    type = "zip"
    source_file = "app/main.py"
    output_path = "app/main.zip"
}


# Creating a lambda function and deploying the main.py file to it
resource "aws_lambda_function" "calculator" {
    function_name = "calculator"
    role = aws_iam_role.lambda_role.arn

    runtime = "python3.12"
    handler = "main.lambda_handler"

    # python file
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

    timeout = 5
    memory_size = 128

    depends_on = [
        aws_iam_role_policy_attachment.lambda_logging
    ]
}


# Creating public HTTP API - Gateway
resource "aws_apigatewayv2_api" "calculator" {
    name = "calculator-api-gateway"
    protocol_type = "HTTP"
}

# Connecting lambda to API - Gateway
resource "aws_apigatewayv2_integration" "calculator" {
    api_id = aws_apigatewayv2_api.calculator.id

    integration_type = "AWS_PROXY"
    integration_method = "POST"
    integration_uri = aws_lambda_function.calculator.invoke_arn
}

# Route the trafic to the calculator endpoint
resource "aws_apigatewayv2_route" "calculator" {
    api_id = aws_apigatewayv2_api.calculator.id

    route_key = "POST /calculator"
    target = "integrations/${aws_apigatewayv2_integration.calculator.id}"
}

resource "aws_apigatewayv2_stage" "default" {
    api_id =  aws_apigatewayv2_api.calculator.id

    name = "$default"
    auto_deploy = true
}


# 8. Permit API Gateway to invoke this Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.calculator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.calculator.execution_arn}/*/*"
}

