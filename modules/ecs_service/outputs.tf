# modules/ecs_service/outputs.tf

output "cluster_name" {
  description = "ECS cluster name — used when updating service via CLI or CI/CD"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name — used when updating service via CLI or CI/CD"
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "Current task definition ARN"
  value       = aws_ecs_task_definition.app.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name — view logs here after deployment"
  value       = aws_cloudwatch_log_group.app.name
}

output "execution_role_arn" {
  description = "Task execution role ARN"
  value       = aws_iam_role.ecs_execution_role.arn
}
