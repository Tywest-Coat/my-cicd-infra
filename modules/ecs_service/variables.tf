# modules/ecs_service/variables.tf

variable "project_name" {
  description = "Used to name all ECS resources consistently"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region — needed for CloudWatch log config inside container definition"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — from VPC module output"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where Fargate tasks will run — from VPC module output"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks — from ALB module output"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN — tasks register here — from ALB module output"
  type        = string
}

variable "ecr_image_uri" {
  description = "Full ECR image URI including tag (e.g. 484632958405.dkr.ecr.us-east-1.amazonaws.com/my-cicd-app:latest)"
  type        = string
}

variable "app_port" {
  description = "Port your Flask container listens on"
  type        = number
  default     = 5000
}

variable "task_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory in MB for the Fargate task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of Fargate tasks to run"
  type        = number
  default     = 1
}
