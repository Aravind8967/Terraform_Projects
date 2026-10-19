variable "region" {
  default = "ap-south-1"
  type    = string
}

variable "environment" {
  default = "dev"
  type    = string
}

variable "db_name" {
  description = "Database name"
  default     = "usersdb"
  type        = string
}

variable "db_username" {
  description = "Database username"
  default     = "admin"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}