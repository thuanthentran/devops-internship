# Mỗi phần tử trong var.repositories tạo ra một repo ECR.
resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name = each.key

  # IMMUTABLE: một tag đã push thì không bị ghi đè.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Giữ tối đa N image mỗi repo, image cũ hơn tự bị xoá.
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

data "aws_iam_policy_document" "this" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [
      for r in aws_ecr_repository.this : r.arn
    ]
  }
}


