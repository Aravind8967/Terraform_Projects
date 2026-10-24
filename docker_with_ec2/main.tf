terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~>6.0"
        }        
    }
}

provider "aws" {
    region = var.region
}


# Check for default vpc and subnet (Prevents billable NAT Gateways)
data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}


# Look up the latest official Amazon ECS-Optimized Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}


# ECR repository
resource "aws_ecr_repository" "fastapi_repo" {
    name = "fastapi-demo-repo"
    image_tag_mutability = "MUTABLE"
    force_delete = true

    image_scanning_configuration {
        scan_on_push = false
    }
}


# ECS Cluster
resource "aws_ecs_cluster" "main" {
    name = "Fastapi-Cluster"
}


# Security Group
resource "aws_security_group" "ecs_sg" {
    name = "fastapi-ecs-sg"
    description = "Allow HTTP inbond to fast-api"
    vpc_id = data.aws_vpc.default.id

    # Inbond and Outbond role for HTTP
    ingress {
        description = "HTTP Inbound"
        from_port = 80
        to_port = 80
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


# IAM Role for EC2 Instance to talk to ECS Control Plane
resource "aws_iam_role" "ec2_ecs_role" {
    name = "fastapi-ec2-ecs-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_node_attach" {
    role = aws_iam_role.ec2_ecs_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
    name = "fastapi-ecs-instance-profile"
    role = aws_iam_role.ec2_ecs_role.name
}


# Self managed EC2 instance
resource "aws_instance" "ecs_node" {
    ami = data.aws_ssm_parameter.ecs_ami.value
    instance_type = var.instance
    iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
    subnet_id = element(data.aws_subnets.default.ids, 0)
    vpc_security_group_ids = [aws_security_group.ecs_sg.id]
    associate_public_ip_address = true

    # Registers this instance with our ECS cluster on boot
    user_data = <<-EOF
                    #!/bin/bash
                    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
                    EOF
    
    root_block_device {
        volume_size = 30
        volume_type = "gp3"
        delete_on_termination = true
    }

    tags = {
        name = "fastapi-ecs-self-managed-node"
    }
}


# ECS Task definition for EC2
resource "aws_ecs_task_definition" "fastapi_task" {
    family = "fastapi-task"
    network_mode = "bridge"
    requires_compatibilities = ["EC2"]
    cpu = "256"
    memory = "256"

    container_definitions = jsonencode([
        {
            name = "fastapi-container"
            image = "${aws_ecr_repository.fastapi_repo.repository_url}:latest"
            cpu = 256
            memory = 256
            essential = true
            portMappings = [
                {
                    containerPort = 80
                    hostPort = 80
                    protocol = "tcp"
                }
            ]
        }
    ])
}

resource "aws_ecs_service" "fastapi_service" {
    name = "fastapi-service"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.fastapi_task.arn
    desired_count = 1
    launch_type = "EC2"

    depends_on = [aws_instance.ecs_node]
}