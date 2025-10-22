output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.hello_world.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.hello_world.name
}

output "ecr_registry_id" {
  description = "Registry ID of the ECR repository"
  value       = aws_ecr_repository.hello_world.registry_id
}

# App Runner Service URL
output "app_runner_service_url" {
  description = "URL of the App Runner service"
  value       = aws_apprunner_service.hello_world.service_url
}

# App Runner Service Status
output "app_runner_service_status" {
  description = "Status of the App Runner service"
  value       = aws_apprunner_service.hello_world.status
}
