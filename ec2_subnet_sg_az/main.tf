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

resource "aws_vpc" "main_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "main-vpc"
        Environment = var.environment
    }
}

resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = var.availability_zone

    tags = {
        Name = "private_subnet"
        Environment = var.environment
    }
}

resource "aws_security_group" "private_sg" {
    name = "web_sg"
    description = "Security group has 80 and 22 inbond rule"
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        description = "Inbond rule of HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Inbond rule for SSH"
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

resource "aws_instance" "ubuntu" {
    count = 2
    ami = var.instance_config.ami
    instance_type = var.instance_config.instance_type
    subnet_id = aws_subnet.private_subnet.id
    vpc_security_group_ids = [ aws_security_group.private_sg.id ]
    associate_public_ip_address = false

    user_data = <<-EOF
        #!/bin/bash
        apt-get update -y
        apt-get install -y apache2
        echo "<h1>this is node ${count.index + 1}</h1> > /var/www/html/index.html
        systemctl start apache2
        systemctl enable apache2
    EOF

    tags = {
        Name = "${var.instance_config.name}-${count.index+1}"
        Environment = var.environment
    }
}