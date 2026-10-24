output "ecr_repository_url" {
    value = aws_ecr_repository.fastapi_repo.repository_url
    description = "ECR url to push the docker image"
}

output "application_ip" {
    value = aws_instance.ecs_node.public_ip
    description = "application running public ip"
}