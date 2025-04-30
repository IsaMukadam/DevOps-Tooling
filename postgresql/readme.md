# AWS RDS PostgreSQL Setup

This directory contains Terraform configurations for deploying a free-tier eligible PostgreSQL database using AWS RDS.

## Features

- Free tier eligible RDS instance (db.t3.micro)
- 20GB GP2 storage
- 7-day backup retention
- Private VPC with two subnets
- Security group for controlled access

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed
3. Your IP address or CIDR block for database access

## Quick Start

1. Navigate to the terraform directory:
```bash
cd terraform
```

2. Update terraform.tfvars with your configuration:
- Set your IP in allowed_cidr
- Set a secure database password
- Modify other values as needed

3. Initialize Terraform:
```bash
terraform init
```

4. Deploy the infrastructure:
```bash
terraform apply
```

## Configuration Options

All configurations can be modified in terraform.tfvars:

- aws_region: AWS region for deployment
- vpc_cidr: CIDR block for the VPC
- allowed_cidr: IP/CIDR allowed to access the database
- database_name: Name of the PostgreSQL database
- database_username: Database admin username
- database_password: Database admin password

## Connecting to the Database

After deployment, Terraform will output:
- Database endpoint
- Connection string
- Database name
- Username

Use these details with your preferred PostgreSQL client to connect.

## Free Tier Limits

This setup stays within AWS free tier limits:
- db.t3.micro instance
- 20GB storage
- Single-AZ deployment
- 7-day backup retention

## Security Notes

- Always restrict allowed_cidr to specific IPs
- Use a strong database password
- The database is in a private subnet
- Access is controlled via security groups

## Clean Up

To remove all resources:
```bash
terraform destroy
```