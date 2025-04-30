output "db_endpoint" {
  description = "The connection endpoint for the database"
  value       = aws_db_instance.postgresql.endpoint
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.postgresql.db_name
}

output "db_username" {
  description = "The master username for the database"
  value       = aws_db_instance.postgresql.username
}

output "db_port" {
  description = "The port the database is listening on"
  value       = 5432
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${aws_db_instance.postgresql.username}:${aws_db_instance.postgresql.password}@${aws_db_instance.postgresql.endpoint}/${aws_db_instance.postgresql.db_name}"
  sensitive   = true
}