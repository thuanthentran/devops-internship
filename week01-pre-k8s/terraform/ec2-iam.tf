data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "music-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "permission" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = [
      for r in aws_ecr_repository.this : r.arn
    ]
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "pull_ecr"
  role   = aws_iam_role.ec2.name
  policy = data.aws_iam_policy_document.permission.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "music-ec2"
  role = aws_iam_role.ec2.name
}
