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

# 1. OIDC provider: AWS tin các token do GitHub ký.
resource "aws_iam_openid_connect_provider" "github" {
  url            = var.github_oidc_url
  client_id_list = ["sts.amazonaws.com"]
}

# 2. Trust policy: ai được nhận role. Điều kiện `sub` giới hạn theo repo và nhánh.
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_subjects
    }
  }
}

# 3. Role cho GitHub Actions. Chưa gắn quyền gì (sẽ thêm policy push ECR sau).
resource "aws_iam_role" "github_actions" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}
