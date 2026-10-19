output "vpc_id" {
    description = "VPC id"
    value = aws_vpc.main_vpc.id
}

output "subnet_id" {
    description = "Subnet ID"
    value = aws_subnet.private_subnet.id
}

output "sg_group_ids" {
    description = "Security group ID"
    value = aws_security_group.private_sg.id
}

output "instance_summary" {
    description = "Instance details"
    value = {
        for idx, instance in aws_instance.ubuntu:
            "instance - ${idx + 1}" => {
                id = instance.id
                arn = instance.arn
                private_ip = instance.private_ip
                public_ip = instance.public_ip
            }
    }
}