variable "aws_region" {
  description = "Region AWS để tạo hạ tầng"
  type        = string
  default     = "ap-southeast-1"
}

variable "repositories" {
  description = "Tên các repo ECR cần tạo (mỗi service một repo)"
  type        = set(string)
  default     = ["music-api", "music-web"]
}

variable "keep_images" {
  description = "Số image giữ lại mỗi repo"
  type        = number
  default     = 10
}

variable "github_oidc_url" {
  description = "URL nơi GitHub phát token OIDC"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "github_subjects" {
  description = "Các workflow GitHub được phép nhận role (định dạng của claim `sub`)"
  type        = list(string)
  default = [
    "repo:thuanthentran/devops-internship:ref:refs/heads/main",
    "repo:thuanthentran/devops-internship:ref:refs/heads/week01/*",
  ]
}

variable "iam_role_name" {
  description = "Tên IAM role cho GitHub Actions"
  type        = string
  default     = "github-actions-ecr"
}
