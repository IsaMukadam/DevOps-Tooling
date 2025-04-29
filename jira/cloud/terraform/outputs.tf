output "jira_public_ip" {
  description = "Public IP address of the Jira EC2 instance"
  value       = aws_instance.jira.public_ip
}

output "jira_dns" {
  description = "Public DNS name of the Jira EC2 instance"
  value       = aws_instance.jira.public_dns
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_connection_string" {
  description = "Database connection string"
  value       = "postgres://jira@${aws_db_instance.postgres.endpoint}/jiradb"
  sensitive   = true
}