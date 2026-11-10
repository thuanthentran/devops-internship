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

# Mỗi phần tử trong var.repositories tạo ra một repo ECR.
resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name = each.key

  # IMMUTABLE: một tag đã push thì không bị ghi đè, nên tag `v1` luôn trỏ đúng một image.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Giữ tối đa N image mỗi repo, image cũ hơn tự bị xoá (tiết kiệm tiền lưu trữ).
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Giữ ${var.keep_images} image gần nhất"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_images
      }
      action = {
        type = "expire"
      }
    }]
  })
}
