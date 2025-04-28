# Jira Server Setup

This directory contains Infrastructure as Code (IaC) for deploying Jira Server on AWS using Terraform and Docker.

## Cloud Infrastructure (AWS)

Located in `/cloud` directory, the setup includes:

### Infrastructure Components
- VPC with public subnet in eu-west-2a
- Internet Gateway for public access
- Security Group allowing ports 80, 443, and 22
- EC2 t2.micro instance (AWS Free Tier eligible)
- 30GB gp2 root volume (AWS Free Tier eligible)

### State Management
- Remote state storage in S3
- State locking with DynamoDB (PAY_PER_REQUEST mode)
- Encryption enabled (AES256)
- Version control for state files

### Docker Configuration
- Uses official Atlassian Jira image
- Memory optimized for t2.micro (384MB min, 768MB max)
- Persistent volume for Jira data
- Automatic container restart

## Quick Start

1. Configure AWS credentials
2. Initialize Terraform:
   ```bash
   cd cloud/terraform
   terraform init
   ```

3. Deploy infrastructure:
   ```bash
   terraform apply
   ```

4. Access Jira:
   - URL will be output after successful deployment
   - Default credentials:
     - Username: admin
     - Password: Set in terraform.tfvars

## Cost Management
- Uses AWS Free Tier eligible resources
- Tagged resources for cost tracking:
  - Environment: "learning"
  - Purpose: "testing"
  - AutoDelete: "true"

## Production Recommendations
This development setup uses a public subnet for both Jira and PostgreSQL for cost-saving during testing. For production deployments, the following architecture changes are recommended:

### Network Architecture
- Place PostgreSQL in a private subnet
- Keep Jira frontend in public subnet
- Implement NAT Gateway for private subnet outbound traffic
- Use Network ACLs for additional subnet-level security

### Security Enhancements
- Restrict PostgreSQL access to only the Jira application security group
- Remove public IP assignment from database instance
- Implement encryption in transit using SSL
- Consider using AWS RDS for managed PostgreSQL with automated backups
- Enable enhanced monitoring and logging

### High Availability Considerations
- Deploy across multiple Availability Zones
- Use Auto Scaling Groups for Jira
- Implement RDS Multi-AZ for database redundancy
- Add Application Load Balancer for Jira instances

### Cost Impact
While the development setup is free tier eligible, production security features will incur costs:
- NAT Gateway (~$32/month)
- Additional subnets in different AZs
- RDS instead of EC2 for PostgreSQL
- Load Balancer for high availability

Alternative cost-optimization approaches for non-production:
- Use NAT Instance (t2.micro) instead of NAT Gateway
- Keep current architecture with strict security groups
- Document and implement proper network isolation in stages

## Security Note
- Remote state is encrypted
- Secure password management via terraform.tfvars (gitignored)
- Public access restricted to necessary ports only