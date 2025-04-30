terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC for monitoring stack
resource "aws_vpc" "monitoring" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-vpc"
  }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.monitoring.id

  tags = {
    Name = "monitoring-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "monitoring-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "prometheus" {
  name        = "prometheus-sg"
  description = "Security group for Prometheus server"
  vpc_id      = aws_vpc.monitoring.id

  # Only allow Grafana to access Prometheus
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana.id]
    description     = "Allow Grafana to access Prometheus"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "prometheus-sg"
    Environment = "monitoring"
    ManagedBy   = "terraform"
    Project     = "postgresql-monitoring"
  }
}

resource "aws_security_group" "grafana" {
  name        = "grafana-sg"
  description = "Security group for Grafana server"
  vpc_id      = aws_vpc.monitoring.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "Grafana web access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "grafana-sg"
    Environment = "monitoring"
    ManagedBy   = "terraform"
    Project     = "postgresql-monitoring"
  }
}

# Prometheus EC2 Instance
resource "aws_instance" "prometheus" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.prometheus.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8  # Minimum size for OS + Prometheus data
    volume_type = "gp2"
    tags = {
      Name = "prometheus-root-volume"
    }
  }

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/templates/prometheus-init.sh", {
    postgres_host = var.postgres_host
  })

  tags = {
    Name        = "prometheus-server"
    Environment = "monitoring"
    ManagedBy   = "terraform"
    Project     = "postgresql-monitoring"
  }
}

# Grafana EC2 Instance
resource "aws_instance" "grafana" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.grafana.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8  # Minimum size for OS + Grafana data
    volume_type = "gp2"
    tags = {
      Name = "grafana-root-volume"
    }
  }

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/templates/grafana-init.sh", {
    prometheus_host = aws_instance.prometheus.private_ip
    grafana_password = var.grafana_password
  })

  # Make sure Grafana starts after Prometheus
  depends_on = [aws_instance.prometheus]

  tags = {
    Name        = "grafana-server"
    Environment = "monitoring"
    ManagedBy   = "terraform"
    Project     = "postgresql-monitoring"
  }
}

# Latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}