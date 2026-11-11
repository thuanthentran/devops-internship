terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Không khai báo access key: provider tự dùng IAM role gắn vào instance (devbox-role).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "devops-internship"
      ManagedBy = "terraform"
    }
  }
}
