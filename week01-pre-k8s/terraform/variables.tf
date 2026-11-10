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
