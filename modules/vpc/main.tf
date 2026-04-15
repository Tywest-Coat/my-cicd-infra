# modules/vpc/main.tf

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # Required: allows AWS services to resolve DNS within VPC
  enable_dns_hostnames = true   # Required: assigns DNS hostnames to EC2/Fargate tasks

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# INTERNET GATEWAY
# Connects the VPC to the public internet.
# Public subnets will route through this.
# ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # "aws_vpc.main.id" = the ID of the VPC we just defined above

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# PUBLIC SUBNETS
# "count" creates one subnet per AZ in our list.
# map_public_ip_on_launch = true means resources
# launched here automatically get a public IP.
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true  # Public subnets assign public IPs automatically

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "public"
  }
}

# ─────────────────────────────────────────
# PRIVATE SUBNETS
# ECS Fargate tasks run here.
# No public IPs — not directly reachable from internet.
# ─────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false  # Private — no public IPs

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "private"
  }
}

# ─────────────────────────────────────────
# ELASTIC IP FOR NAT GATEWAY
# NAT Gateway needs a static public IP address.
# "domain = vpc" is required for VPC-scoped EIPs.
# ─────────────────────────────────────────
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]  # EIP must be created after IGW exists

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# NAT GATEWAY
# Lives in the FIRST public subnet.
# Private subnets route outbound traffic through
# this so ECS tasks can reach the internet (to
# pull images from ECR) without being exposed.
# ─────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Always place NAT in a PUBLIC subnet

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.project_name}-nat"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────
# PUBLIC ROUTE TABLE
# Routes all outbound internet traffic (0.0.0.0/0)
# to the Internet Gateway.
# ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Associate BOTH public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────
# PRIVATE ROUTE TABLE
# Routes all outbound internet traffic (0.0.0.0/0)
# through the NAT Gateway — NOT the IGW.
# This is the key difference: private resources
# can call OUT but can't be reached from outside.
# ─────────────────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Associate BOTH private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
