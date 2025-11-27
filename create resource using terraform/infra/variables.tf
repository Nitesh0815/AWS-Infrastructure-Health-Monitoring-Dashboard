variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A unique name for this project, used as a prefix for resources. Must only contain lowercase alphanumeric characters, hyphens, and underscores."
  type        = string
  default     = "monitordashboard"
}

variable "ec2_instance_type" {
  description = "The EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}

variable "ec2_ami_id" {
  description = "The AMI ID for the EC2 instance (e.g., Amazon Linux 2023)"
  type        = string
  default     = "ami-053b0d53c279acc90" # Example: Amazon Linux 2023 in us-east-1. FIND LATEST!
}

variable "admin_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = "your-email@example.com" # REPLACE THIS WITH YOUR EMAIL
}

variable "db_master_username" {
  description = "Master username for the RDS database"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "Master password for the RDS database"
  type        = string
  sensitive   = true # Mark as sensitive to prevent showing in logs
  default     = "MyTerraformPassword123!" # REPLACE WITH A STRONG PASSWORD
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}