# modules/alb/main.tf

# ─────────────────────────────────────────
# ALB SECURITY GROUP
# This SG is attached to the load balancer itself.
# It allows anyone on the internet (0.0.0.0/0)
# to reach port 80 — this is intentional,
# the ALB is designed to be public-facing.
# ─────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls traffic to and from the Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# Allow HTTP traffic from the entire internet into the ALB
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTP from internet"
}

# Allow all outbound traffic from the ALB to reach ECS tasks
# The ALB needs to forward traffic to tasks on their app port
resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"   # -1 means ALL protocols
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound from ALB"
}

# ─────────────────────────────────────────
# ECS TASK SECURITY GROUP
# This SG is attached to the Fargate tasks.
# It ONLY allows traffic from the ALB SG above.
# This is security group chaining — the ECS tasks
# are completely unreachable from the internet.
# ─────────────────────────────────────────
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Controls traffic to ECS Fargate tasks  only ALB can reach them"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Allow traffic on the app port ONLY from the ALB security group
# referenced_security_group_id means: "only if source has this SG"
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id   # SG chaining — key security pattern
  description                  = "Allow traffic from ALB only"
}

# Allow all outbound from ECS tasks — needed so containers can:
# - Pull Docker images from ECR
# - Call AWS APIs (CloudWatch Logs, Secrets Manager, etc.)
# - Reach the internet if needed
resource "aws_vpc_security_group_egress_rule" "ecs_all_outbound" {
  security_group_id = aws_security_group.ecs_tasks.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound from ECS tasks"
}

# ─────────────────────────────────────────
# APPLICATION LOAD BALANCER
# Lives in public subnets across both AZs.
# internal = false means it's internet-facing.
# ─────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false                   # Public-facing — has a public DNS name
  load_balancer_type = "application"           # ALB (vs. NLB for TCP/UDP)
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids   # Must be in public subnets

  enable_deletion_protection = false           # Set true in production to prevent accidental deletion

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# TARGET GROUP
# Defines WHERE the ALB sends traffic.
# target_type = "ip" is REQUIRED for Fargate —
# tasks are registered by private IP, not instance ID.
# ─────────────────────────────────────────
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"   # MUST be "ip" for Fargate — not "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path   # ALB pings this path on your Flask app
    port                = "traffic-port"          # Uses the same port as the target group (5000)
    protocol            = "HTTP"
    matcher             = "200"                   # A 200 OK response = healthy
    interval            = 30                      # Check every 30 seconds
    timeout             = 5                       # Wait 5 seconds for a response
    healthy_threshold   = 2                       # 2 consecutive successes = healthy
    unhealthy_threshold = 3                       # 3 consecutive failures = unhealthy → replace task
  }

  # Important: allows Terraform to update the target group
  # even if the name hasn't changed (avoids destroy/recreate cycle)
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# ALB LISTENER
# Defines WHAT the ALB listens for.
# Port 80, HTTP → forward to target group.
# This is the rule that connects the ALB to ECS.
# ─────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name        = "${var.project_name}-listener"
    Environment = var.environment
  }
}
