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

# Security Group for PostgreSQL
resource "aws_security_group" "postgres" {
  name        = "postgres-security-group"
  description = "Security group for PostgreSQL Database"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jira.id]
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
    Name        = "postgres-sg"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# EC2 Instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "jira" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jira.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
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

              echo "Waiting for PostgreSQL to be ready..."
              until PGPASSWORD="${var.db_password}" psql -h ${aws_instance.postgres.private_ip} -U jira -d jiradb -c '\q' 2>/dev/null; do
                echo "PostgreSQL is unavailable - sleeping 5s"
                sleep 30
              done
              echo "PostgreSQL is ready!"

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
              POSTGRES_HOST=${aws_instance.postgres.private_ip}
              EOL

              # Start Jira using docker-compose
              cd /opt/jira
              docker-compose up -d
              EOF

  metadata_options {
    http_endpoint               = "enabled"  # Enable the instance metadata service
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1          # Restrict token usage to immediate network
    instance_metadata_tags      = "disabled" # Additional security measure
  }

  tags = {
    Name        = "jira-server"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}

# EC2 Instance for PostgreSQL
resource "aws_instance" "postgres" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y postgresql postgresql-contrib

              # Configure PostgreSQL to accept connections
              sudo -u postgres bash -c "psql -c \"ALTER USER postgres PASSWORD '${var.db_password}';\""
              
              # Update PostgreSQL configuration
              echo "listen_addresses = '*'" >> /etc/postgresql/12/main/postgresql.conf
              echo "host all all ${aws_subnet.public.cidr_block} md5" >> /etc/postgresql/12/main/pg_hba.conf
              
              # Create Jira database and user
              sudo -u postgres bash -c "psql -c \"CREATE DATABASE jiradb;\""
              sudo -u postgres bash -c "psql -c \"CREATE USER jira WITH PASSWORD '${var.db_password}';\""
              sudo -u postgres bash -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE jiradb TO jira;\""
              
              

              # Restart PostgreSQL
              systemctl restart postgresql
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  tags = {
    Name        = "postgres-server"
    Environment = "learning"
    Purpose     = "testing"
    AutoDelete  = "true"
  }
}
