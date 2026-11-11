output "repository_urls" {
  description = "URL của từng repo ECR, dùng khi docker tag/push và trong CI"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARN của từng repo ECR (dùng để giới hạn quyền cho role CI)"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
