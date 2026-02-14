variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-south-1"  # Mumbai
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
  default     = "ap-southeast-1"  # Singapore
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "project-nova"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "Admin123!"  # CHANGE THIS!
}

variable "alert_email" {
  description = "Email address for DR alerts"
  type        = string
  default     = "admin@example.com"  # CHANGE THIS!
}
