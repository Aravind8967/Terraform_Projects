terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_security_group" "db_sg" {
    name = "db_sg"
    description = "Mysql DB security group with 3306 access"
    vpc_id = data.aws_vpc.default.id

    ingress {
        description = "Database access port"
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    }

    ingress {
        description = "Database SSH access port"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_db_subnet_group" "default" {
    name = "db_subnet_group"
    subnet_ids = data.aws_subnets.default.ids

    tags = {
        Name = "Database subnet group"
    }
}

resource "aws_db_instance" "Mysql" {
    identifier = "mysql-db"
    allocated_storage = var.db_config.allocated_storage
    max_allocated_storage = var.db_config.max_allocated_storage
    storage_type = var.db_config.storage_type
    engine = var.db_config.engine
    engine_version = var.db_config.engine_version
    instance_class = var.db_config.instance_class
    db_name = var.db_config.db_name
    username = var.db_config.username
    password = var.db_password
    publicly_accessible = true
    db_subnet_group_name = aws_db_subnet_group.default.name
    vpc_security_group_ids = [aws_security_group.db_sg.id]
    skip_final_snapshot = true          # Do NOT take a manual snapshot before deleting
    delete_automated_backups = true     # Automatically delete all daily system-generated automated backups
    backup_retention_period = 0         # Disable retention window (set to 0 days)
}