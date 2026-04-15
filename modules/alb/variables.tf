# modules/alb/variables.tf

variable "project_name" {
  description = "Used to name all ALB resources consistently"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — received from VPC module output"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB — received from VPC module output"
  type        = list(string)
}

variable "app_port" {
  description = "The port your Flask app listens on inside the container"
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "The URL path the ALB uses to check container health"
  type        = string
  default     = "/health"
}
