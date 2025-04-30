variable "aws_region" {
  description = "AWS region to deploy the resources"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr" {
  description = "CIDR block allowed to connect to the database"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "postgresdb"
}

variable "database_username" {
  description = "Username for the database"
  type        = string
  default     = "dbadmin"
}

variable "database_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}