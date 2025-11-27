terraform {
  required_version = "~> 1.0" # Specify a compatible Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a recent AWS provider version
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}