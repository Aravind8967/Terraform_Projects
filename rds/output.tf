output "vpc_id" {
    description = "default vpc id"
    value = data.aws_vpc.default.id
}

output "my_ip" {
    description = "my ip address"
    value = data.http.my_ip.response_body
}

output "subnet" {
    value = data.aws_subnets.default.id
}