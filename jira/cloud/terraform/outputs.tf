output "jira_public_ip" {
  description = "Public IP address of the Jira server"
  value       = aws_instance.jira.public_ip
}

output "jira_url" {
  description = "URL to access Jira"
  value       = "http://${aws_instance.jira.public_ip}"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.jira_vpc.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.jira.id
}

output "postgres_private_ip" {
  description = "Private IP of PostgreSQL instance"
  value       = aws_instance.postgres.private_ip
}

output "postgres_public_ip" {
  description = "Public IP of PostgreSQL instance"
  value       = aws_instance.postgres.public_ip
}