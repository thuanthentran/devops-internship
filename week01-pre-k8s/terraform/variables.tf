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

variable "iam_role" {
  description = "Tên IAM role cho GitHub Actions"
  type        = string
  default     = "github-actions-ecr"
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
    "repo:thuanthentran@158747017/devops-internship@1451498040:ref:refs/heads/main",
    "repo:thuanthentran@158747017/devops-internship@1451498040:ref:refs/heads/week01/*"
  ]
}

variable "instance_type" {
  description = "Xài instance bự cỡ nào đây"
  type        = string
  default     = "c7i-flex.large"
}

variable "devbox_sg_id" {
  type    = string
  default = "sg-0d0ffc9f3028230e3"
}
