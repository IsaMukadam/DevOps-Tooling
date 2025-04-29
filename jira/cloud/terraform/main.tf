terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "jira-terraform-state-learning"
    key            = "jira/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "jira_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "jira-vpc"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.jira_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "jira-public-subnet"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# Private Subnet for RDS
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.jira_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "jira-private-subnet-1"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.jira_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 3)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "jira-private-subnet-2"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.jira_vpc.id

  tags = {
    Name        = "jira-igw"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.jira_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "jira-public-rt"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "jira" {
  name        = "jira-security-group"
  description = "Security group for Jira Server"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "jira-sg"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "rds-security-group"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jira.id]
  }

  tags = {
    Name        = "rds-sg"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "jira" {
  name        = "jira-db-subnet-group"
  description = "Subnet group for Jira RDS"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name        = "jira-db-subnet-group"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# RDS Instance
resource "aws_db_instance" "postgres" {
  identifier           = "jira-postgres"
  engine              = "postgres"
  engine_version      = "14"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp2"
  db_name             = "jiradb"
  username            = "jira"
  password            = var.db_password
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.jira.name

  backup_retention_period = 7
  multi_az               = false
  publicly_accessible    = false

  tags = {
    Name        = "jira-rds"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# EC2 Instance for Jira
resource "aws_instance" "jira" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jira.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8  # Free tier limit is 30GB total across all volumes
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io postgresql-client
              
              curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              systemctl start docker
              systemctl enable docker

              echo "Waiting for RDS to be ready..."
              until PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.endpoint} -U jira -d jiradb -c '\q' 2>/dev/null; do
                echo "RDS is unavailable - sleeping 30s"
                sleep 30
              done
              echo "RDS is ready!"

              # Create docker-compose directory
              mkdir -p /opt/jira

              # Copy docker-compose configuration
              cat > /opt/jira/docker-compose.yml << 'COMPOSE'
              ${file("${path.module}/../docker/docker-compose.yml")}
              COMPOSE

              # Set environment variables
              cat > /opt/jira/.env << EOL
              JIRA_ADMIN_PASSWORD=${var.jira_admin_password}
              DB_PASSWORD=${var.db_password}
              POSTGRES_HOST=${aws_db_instance.postgres.endpoint}
              EOL

              # Start Jira using docker-compose
              cd /opt/jira
              docker-compose up -d
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  tags = {
    Name        = "jira-server"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}
