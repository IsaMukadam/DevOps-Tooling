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

# VPC Configuration
resource "aws_vpc" "postgresql_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "postgresql-vpc"
  }
}

# Create two private subnets in different AZs (required for RDS)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.postgresql_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "postgresql-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.postgresql_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "postgresql-private-2"
  }
}

# Security Group for RDS
resource "aws_security_group" "postgresql" {
  name        = "postgresql-security-group"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.postgresql_vpc.id

  # You should replace this with your specific IP or security group
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  tags = {
    Name = "postgresql-sg"
  }
}

# Subnet group for RDS
resource "aws_db_subnet_group" "postgresql" {
  name        = "postgresql-subnet-group"
  description = "Subnet group for PostgreSQL RDS"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "postgresql-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "postgresql" {
  identifier = "postgresql-db"

  # Free tier settings
  engine               = "postgres"
  engine_version      = "14"
  instance_class      = "db.t3.micro"  # Free tier eligible
  allocated_storage   = 20             # Free tier eligible
  storage_type        = "gp2"

  # Database settings
  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  # Network settings
  db_subnet_group_name   = aws_db_subnet_group.postgresql.name
  vpc_security_group_ids = [aws_security_group.postgresql.id]
  publicly_accessible    = false

  # Backup settings
  backup_retention_period = 7    # Free tier eligible
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Other settings
  multi_az               = false  # Free tier requires single AZ
  skip_final_snapshot    = true   # For testing purposes

  tags = {
    Name = "postgresql-db"
  }
}