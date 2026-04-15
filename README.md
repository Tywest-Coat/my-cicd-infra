# AWS Infrastructure as Code (Terraform)

A production-grade, highly available AWS architecture built entirely with Terraform. This repository provisions the secure networking, compute, and load balancing infrastructure required to run a containerized Python Flask API (deployed via GitHub Actions).

## 🏗 Architecture Overview






- **Network:** Custom VPC, 2 Public Subnets (ALB), 2 Private Subnets (ECS Fargate).
- **Routing:** Internet Gateway for public ingress, NAT Gateway for secure private egress.
- **Compute:** Serverless AWS ECS Fargate cluster.
- **Load Balancing:** Application Load Balancer (ALB) routing HTTP traffic to healthy containers.
- **State Management:** Remote S3 Backend with native state locking (`use_lockfile = true`) and AES-256 encryption.

## 🛠 Tech Stack

| Category | Technology |
|---|---|
| **IaC Tool** | Terraform (v1.10+) |
| **Cloud Provider** | Amazon Web Services (AWS) |
| **Compute** | ECS Fargate, ECR |
| **Networking** | VPC, ALB, NAT Gateway, IGW |
| **Security** | IAM, Security Groups (Chaining) |
| **Observability** | CloudWatch Logs |

## 🔒 Security Highlights

1. **Private Compute Isolation:** ECS tasks run exclusively in private subnets. They have no public IP addresses and cannot be reached directly from the internet.
2. **Security Group Chaining:** Fargate tasks only accept ingress traffic originating from the Application Load Balancer's specific Security Group ID.
3. **IAM Least Privilege:** Strict separation between the **Task Execution Role** (allows ECS agent to pull images and write logs) and the **Task Role** (permissions for the application code itself).
4. **Secure State:** Terraform state is stored remotely in an S3 bucket with versioning, encryption at rest, and public access blocked.

## 📁 Project Structure

```text
my-cicd-infra/
├── main.tf                 # Root module wiring and backend configuration
├── providers.tf            # AWS provider and version constraints
├── variables.tf            # Input variables
├── outputs.tf              # Global outputs (ALB DNS, Cluster Name)
└── modules/
    ├── vpc/                # VPC, Subnets, IGW, NAT, Route Tables
    ├── alb/                # Load Balancer, Target Group, Listeners, Security Groups
    └── ecs_service/        # ECS Cluster, Task Def, Service, IAM Roles, CloudWatch
```

## 🚀 How to Deploy

### 1. Prerequisites
- AWS CLI installed and configured (`aws configure`)
- Terraform installed (`>= 1.10`)
- S3 state bucket manually created for the remote backend

### 2. Initialize
Downloads AWS providers and configures the S3 backend.
```bash
terraform init
```

### 3. Plan
Previews the infrastructure changes.
```bash
terraform plan
```

### 4. Apply
Provisions the infrastructure in AWS.
```bash
terraform apply
```
*Upon completion, Terraform will output the `alb_dns_name` — your application's public URL.*

## 🔄 CI/CD Integration

This infrastructure acts as the deployment target for the application's CI/CD pipeline. The GitHub Actions workflow in the application repository:
1. Builds and pushes the new Docker image to ECR.
2. Dynamically renders the task definition with the latest image tag.
3. Triggers a zero-downtime rolling deployment to the ECS service created by this Terraform code.
