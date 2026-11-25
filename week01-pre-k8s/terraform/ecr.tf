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
    rules = [
      {
        rulePriority = 1
        description  = "Giữ ${var.keep_images} image có tag gần nhất"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.keep_images
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Xoá image không tag sau 1 ngày"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]

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
      "ecr:PutImage",
      "ecr:BatchGetImage"
    ]
    resources = [
      for r in aws_ecr_repository.this : r.arn
    ]
  }
}


