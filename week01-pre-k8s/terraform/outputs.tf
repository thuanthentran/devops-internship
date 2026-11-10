output "repository_urls" {
  description = "URL của từng repo ECR, dùng khi docker tag/push và trong CI"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
