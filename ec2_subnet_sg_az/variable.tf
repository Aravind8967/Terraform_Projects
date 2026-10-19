variable "environment" {
    default = "dev"
    type = string
}

variable "region" {
    default = "ap-south-1"
    type = string
}

variable "availability_zone" {
    default = "ap-south-1a"
    type = string
}

variable "instance_config" {
    description = "Instance cofiguration"

    type = object({
        ami = string
        instance_type = string
        name = string
    })

    default = {
        ami = "ami-006f82a1d5a27da54"
        instance_type = "t3.micro"
        name = "ubuntu-Node"
    }
}