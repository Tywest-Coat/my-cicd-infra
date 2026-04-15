# modules/alb/outputs.tf

output "alb_dns_name" {
  description = "The public DNS name of the ALB — paste this in your browser to reach the app"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN — needed by the ECS service to register with the listener"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target group ARN — the ECS service registers task IPs here"
  value       = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  description = "ALB SG ID — passed to ECS module for security group chaining"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ECS tasks SG ID — attached to Fargate tasks so only ALB can reach them"
  value       = aws_security_group.ecs_tasks.id
}
