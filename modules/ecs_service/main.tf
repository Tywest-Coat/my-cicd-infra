# modules/ecs_service/main.tf

# ─────────────────────────────────────────
# CLOUDWATCH LOG GROUP
# Where your container stdout/stderr logs go.
# Created FIRST so the task definition can
# reference it by name.
# retention_in_days = 7 keeps costs near zero
# for dev — set to 30 or 90 in production.
# ─────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# IAM — TASK EXECUTION ROLE
# Used by the ECS AGENT (not your app) to:
#   - Pull Docker image from ECR
#   - Write container logs to CloudWatch
#
# Step 1: Create the role with a trust policy
# that allows ECS tasks to assume it.
# ─────────────────────────────────────────
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  # Trust policy: defines WHO can assume this role
  # "ecs-tasks.amazonaws.com" = the ECS agent service
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-execution-role"
    Environment = var.environment
  }
}

# Step 2: Attach AWS's managed policy for ECS execution
# AmazonECSTaskExecutionRolePolicy grants:
#   - ecr:GetAuthorizationToken
#   - ecr:BatchGetImage (pull images)
#   - logs:CreateLogStream + PutLogEvents (write logs)
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ─────────────────────────────────────────
# IAM — TASK ROLE
# Used by YOUR APPLICATION CODE while running.
# Your Flask app doesn't call other AWS services
# yet, so this is minimal — but it must exist.
# When you add S3, DynamoDB, etc. later, you'll
# attach policies HERE (not to the execution role).
# ─────────────────────────────────────────
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-task-role"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# ECS CLUSTER
# A logical grouping of tasks and services.
# With Fargate, the cluster is just a namespace —
# AWS manages the underlying servers for you.
# container_insights enables enhanced CloudWatch
# metrics for the cluster.
# ─────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# ECS TASK DEFINITION
# The blueprint for your container. Defines:
#   - How much CPU and memory to allocate
#   - What image to run
#   - What port to expose
#   - Where to send logs
#   - Which IAM roles to use
#
# jsonencode() converts HCL to the JSON format
# AWS expects for container_definitions.
# ─────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]   # Serverless — no EC2 instances to manage
  network_mode             = "awsvpc"      # Required for Fargate — each task gets its own ENI
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn  # For ECS agent
  task_role_arn            = aws_iam_role.ecs_task_role.arn        # For app code

  container_definitions = jsonencode([
    {
      name      = var.project_name   # This name MUST match the load_balancer block in the service below
      image     = var.ecr_image_uri  # Full ECR URI — updated by GitHub Actions on every push
      essential = true               # If this container stops, the entire task stops

      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port  # For awsvpc mode, containerPort == hostPort
          protocol      = "tcp"
        }
      ]

      # awslogs driver ships container stdout/stderr to CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"   # Logs appear as ecs/container-name/task-id
        }
      }

      # Environment variables available to your Flask app
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-def"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# ECS SERVICE
# Keeps your desired number of tasks running.
# If a task crashes, the service replaces it.
# This is what connects your task definition
# to the ALB target group.
#
# Rolling deployment settings:
#   minimum_healthy_percent = 100 → never kill
#     old task until new one is healthy
#   maximum_percent = 200 → allows running
#     2x tasks during deployment window
# These two settings together = zero downtime.
# ─────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Network config: run tasks in PRIVATE subnets
  # assign_public_ip = false because NAT Gateway
  # handles outbound traffic for private subnets
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  # Wire this service to the ALB target group
  # container_name MUST exactly match the name
  # field in the container_definitions above
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.project_name
    container_port   = var.app_port
  }

  # Zero-downtime rolling deployments
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Circuit breaker: automatically rolls back if
  # new tasks fail to reach healthy state
  # This is what gave you auto-rollback in Project 1
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Grace period gives new tasks time to start up
  # before the ALB begins health checking them
  health_check_grace_period_seconds = 60

  # Ensures ALB listener exists before service
  # tries to register tasks with the target group
  depends_on = [aws_iam_role_policy_attachment.ecs_execution_role_policy]

  # Tells Terraform to ignore desired_count changes
  # made outside Terraform (e.g., by an auto-scaler)
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name        = "${var.project_name}-service"
    Environment = var.environment
  }
}
