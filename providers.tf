# providers.tf

terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }

  # Remote state backend — S3 with native locking
  backend "s3" {
    bucket       = "tywest-terraform-state"
    key          = "my-cicd-infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true   # Native S3 locking — replaces DynamoDB
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}
