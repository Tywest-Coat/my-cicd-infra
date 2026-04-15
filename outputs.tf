# outputs.tf

output "alb_dns_name" {
  description = "Your app's public URL"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_service.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_service.service_name
}

output "cloudwatch_log_group" {
  description = "View your container logs here"
  value       = module.ecs_service.cloudwatch_log_group
}
