output "repository_urls" {
  description = "URL của từng repo ECR, dùng khi docker tag/push và trong CI"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARN của từng repo ECR (dùng để giới hạn quyền cho role CI)"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}

output "public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_eip.this.public_ip
}

output "private_ip" {
  description = "Private IP of EC2 instance"
  value       = module.ec2_instance.private_ip
}

output "name_servers" {
  description = "Name server của zone Route53"
  value       = aws_route53_zone.prod.name_servers
}

output "rke2_server_private_ip" {
  description = "Private IP của RKE2 server"
  value       = module.k8s_instance.private_ip
}
