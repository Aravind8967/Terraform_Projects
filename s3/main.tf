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
  bucket = "aru8967testbucket11234"

  tags = {
    Name        = "my bucket 2.0"
    Environment = "Dev"
  }
}
