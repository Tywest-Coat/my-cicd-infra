# main.tf

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
}


module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id               # ← output from VPC module
  public_subnet_ids = module.vpc.public_subnet_ids    # ← output from VPC module
  app_port          = 5000
  health_check_path = "/health"
}


module "ecs_service" {
  source = "./modules/ecs_service"

  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids       # From VPC module
  ecs_tasks_security_group_id = module.alb.ecs_tasks_security_group_id  # From ALB module
  target_group_arn            = module.alb.target_group_arn             # From ALB module
  ecr_image_uri               = "484632958405.dkr.ecr.us-east-1.amazonaws.com/my-cicd-app:latest"
  app_port                    = 5000
  task_cpu                    = 256
  task_memory                 = 512
  desired_count               = 1
}
