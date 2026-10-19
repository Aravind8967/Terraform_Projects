terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}


# Creates VPC and keep the lambda and RDS 
resource "aws_vpc" "app" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "users-api-vpc"
  }
}

# Creating subnet_1 avalability_zone ap-south-1a
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "users-subnet-a"
  }
}

# Creating subnet_1 avalability_zone ap-south-1a
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "users-subnet-b"
  }
}


# Lambda network interface security group
resource "aws_security_group" "lambda_sg" {
  name   = "user-lambda-sg"
  vpc_id = aws_vpc.app.id

  # outbond connect to RDS and Secrets Manager
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the REST API
resource "aws_api_gateway_rest_api" "users_api" {
  name        = "users_rest_api"
  description = "REST - API for users CRUD operation"
}


# Create /users endpoint
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.users_api.id
  parent_id   = aws_api_gateway_rest_api.users_api.root_resource_id
  path_part   = "users"
}


# Method for /users
resource "aws_api_gateway_method" "users_methods" {
  for_each      = toset(["GET", "POST"])
  rest_api_id   = aws_api_gateway_rest_api.users_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = each.value
  authorization = "NONE"
}


# Transfer the data as body in json form
resource "aws_api_gateway_integration" "users" {
  for_each = aws_api_gateway_method.users_methods

  rest_api_id             = aws_api_gateway_rest_api.users_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.users_handler.invoke_arn
}


# Create /users/{user_id}   endpoint
resource "aws_api_gateway_resource" "user_id" {
  rest_api_id = aws_api_gateway_rest_api.users_api.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{user_id}"
}



# Method for /users/{user_id}
resource "aws_api_gateway_method" "user_id_methods" {
  for_each = toset(["GET", "PUT", "DELETE"])

  rest_api_id   = aws_api_gateway_rest_api.users_api.id
  resource_id   = aws_api_gateway_resource.user_id.id
  http_method   = each.value
  authorization = "NONE"
}


# Transfer the data as body in json form
resource "aws_api_gateway_integration" "user_id" {
  for_each = aws_api_gateway_method.user_id_methods

  rest_api_id             = aws_api_gateway_rest_api.users_api.id
  resource_id             = aws_api_gateway_resource.user_id.id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.users_handler.invoke_arn
}


# staging the api gateway
resource "aws_api_gateway_deployment" "users" {
    rest_api_id = aws_api_gateway_rest_api.users_api.id

    depends_on = [ 
        aws_api_gateway_integration.users,
        aws_api_gateway_integration.user_id,
        aws_api_gateway_integration.query_post
    ]
}

resource "aws_api_gateway_stage" "users_stage" {
    rest_api_id = aws_api_gateway_rest_api.users_api.id
    deployment_id = aws_api_gateway_deployment.users.id
    stage_name = "dev"

    description = "Development stage for users API"
}


# -------- API gateway for /query (custom query execute) --------

resource "aws_api_gateway_resource" "query" {
  rest_api_id = aws_api_gateway_rest_api.users_api.id
  parent_id   = aws_api_gateway_rest_api.users_api.root_resource_id
  path_part   = "query"
}

resource "aws_api_gateway_method" "query_post" {
  rest_api_id   = aws_api_gateway_rest_api.users_api.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_post" {
  rest_api_id             = aws_api_gateway_rest_api.users_api.id
  resource_id             = aws_api_gateway_resource.query.id
  http_method             = aws_api_gateway_method.query_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.users_handler.invoke_arn
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

# IAM policy for lambda function
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "app"
  output_path = "app.zip"
}


# Creating Lambda function
resource "aws_lambda_function" "users_handler" {
  function_name = "user-crud-handler"
  role          = aws_iam_role.lambda_role.arn

  runtime = "python3.12"
  handler = "main.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = base64sha256(data.archive_file.lambda_zip.output_path)

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.lambda_sg.id
    ]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.users_db.address
      DB_PORT     = "3306"
      DB_NAME     = var.db_name
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
    }
  }

  timeout     = 15
  memory_size = 128

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logging
  ]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowUsersApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.users_api.execution_arn}/*/*"
}


# RDS accepts MySQL connections only from lambda
resource "aws_security_group" "rds" {
  name   = "users-rds-sg"
  vpc_id = aws_vpc.app.id

  ingress {
    description     = "MySQL from Lambda only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_subnet_group" "app" {
  name = "users-db-subnets"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "users-db-subnets"
  }
}

# Creating the database
resource "aws_db_instance" "users_db" {
  identifier = "users-api-mysql"

  engine         = "mysql"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "users-api-mysql"
  }
}


resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# --------------------- AWS secret manager ---------------------------
# basically secret manager into vpc need to this to existing vpc 
# so internal resources (like lambda) can access 

# Store RDS credentials in secrets managers
# resource "aws_secretsmanager_secret" "db_credentials" {
#     name = "users-api/mysql-credentials"
#     recovery_window_in_days = 0
# }

# resource "aws_secretsmanager_secret_version" "db_credentials" {
#     secret_id = aws_secretsmanager_secret.db_credentials.id

#     secret_string = jsonencode({
#         host = aws_db_instance.users_db.address
#         port = 3306
#         username = var.db_username
#         password = var.db_password
#         database = var.db_name
#     })
# }

# Lambda can reach secret managers privately, without a NAT gateway
# resource "aws_security_group" "secrets_endpoint" {
#     name = "users-secrets-endpoint-sg"
#     vpc_id = aws_vpc.app.id

#     # secrets manager api call normally happens with 443 port
#     ingress {
#         from_port = 443
#         to_port = 443
#         protocol = "tcp"
#         security_groups = [aws_security_group.lambda_sg.id]
#     }

#     egress {
#         from_port = 0
#         to_port = 0
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
# }

# resource "aws_vpc_endpoint" "secret_manager" {
#     vpc_id = aws_vpc.app.id
#     service_name = "com.amazonaws.${var.region}.secretsmanager"
#     vpc_endpoint_type = "Interface"
#     subnet_ids = [aws_subnet.private_a.id]
#     security_group_ids = [aws_security_group.secrets_endpoint.id]
#     private_dns_enabled = true
# }

# resource "aws_iam_role_policy" "read_db_secret" {
#   name = "read-users-db-secret"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = ["secretsmanager:GetSecretValue"]
#       Resource = aws_secretsmanager_secret.db_credentials.arn
#     }]
#   })
# }