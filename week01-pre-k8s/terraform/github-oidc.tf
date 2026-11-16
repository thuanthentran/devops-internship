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

# 3. Role cho GitHub Actions (chỉ một role, không phải mỗi repo một role).
#    Chưa gắn quyền gì, policy push ECR sẽ thêm sau.
resource "aws_iam_role" "github_actions" {
  name               = var.iam_role
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}
resource "aws_iam_role_policy" "github_ecr_push" {
  name   = "push_ecr"
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.this.json
}
