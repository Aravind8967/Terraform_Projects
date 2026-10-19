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


resource "aws_s3_bucket" "bucket1" {
  bucket = "aru8967testbucket12345"
  tags = {
    Name        = "${var.environment}-Bucket 1"
    Environment = var.environment
  }
}
