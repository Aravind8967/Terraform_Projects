terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "environment" {
  default = "dev"
  type    = string
}

variable "sg_name" {
  default = "security_group1"
  type    = string
}

resource "aws_security_group" "security_group1" {
  name        = var.sg_name
  description = "this is test security group for trail it is created"
  vpc_id      = "vpc-03c217309be0a7a9e"

  ingress {
    description = "SSH from anyware"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http accessable"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https accessable"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = var.sg_name
    Environment = var.environment
  }
}

resource "aws_instance" "ubuntu" {
  count         = 2
  ami           = "ami-006f82a1d5a27da54"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.security_group1.id]

  tags = {
    Name        = "${var.environment}-ec2-instance-${count.index}"
    Environment = var.environment
  }
}

output "instance_id" {
  description = "this is ubuntu instance id"
  value       = aws_instance.ubuntu[*].id
}

output "vpc_id" {
  description = "vpc id"
  value       = aws_security_group.security_group1.vpc_id
}

output "sg_id" {
  description = "security group id"
  value       = aws_security_group.security_group1.id
}
