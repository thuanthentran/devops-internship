# devops-internship

Repo thực tập DevOps 12 tuần. Tuần 1: DevOps trước thời Kubernetes.
Người dùng giao tiếp bằng tiếng Việt, đang học: giải thích ngắn gọn khái niệm khi làm.

## Môi trường
- Dev box: EC2 t3.small, Ubuntu 24.04, region ap-southeast-1, 2GB RAM + 2GB swap.
- AWS auth: IAM role `devbox-role` gắn vào instance. KHÔNG tạo/dùng access key, KHÔNG `aws configure` với key.
- Tools: docker + compose plugin, awscli v2, terraform, ansible.
- RAM ít: không build image Java/Rails trên dev box, build bằng GitHub Actions.
- Tài khoản AWS cá nhân, tự trả tiền: ưu tiên free tier, nhắc stop instance, ECR lifecycle giữ 10 image.

## Mục tiêu tuần 1
App ghi lại sở thích nghe nhạc (chỉ hiển thị, có link Spotify/Apple Music, không phát nhạc).
- DB chính Postgres: `artists`, `genres`, `songs`, `playlists`, `playlist_songs` (N-N).
- DB phụ (bonus): MySQL (cùng schema), MongoDB (ghi chú/review), Redis (cache, đếm lượt xem),
  DynamoDB (`listening_history`).
- React frontend (`app.<domain>`) + Node API (`node.<domain>`).
- Sau đó: python, go, php, spring, quarkus, rails, mỗi ngôn ngữ một service nhỏ đọc DB, subdomain riêng.
- Deploy: docker compose trên 1 EC2 lớn tạo bằng Terraform, nginx reverse proxy, certbot HTTPS,
  Route53 subdomain. Tên miền: chưa mua.
- CI: GitHub Actions build → ECR, đăng nhập bằng OIDC role `github-actions-ecr` (không static key).
- Terraform tạo hạ tầng; Ansible cấu hình + deploy lại (sau khi bản user_data chạy được).

## Thứ tự làm
1. Schema + seed Postgres
2. Node API + React, chạy bằng docker compose trên dev box
3. Terraform: OIDC provider + role + ECR repos; workflow `.github/workflows/build-push-ecr.yml`
4. Terraform EC2 lớn + nginx
5. Route53 + certbot
6. Thêm ngôn ngữ / DB phụ

## Quy ước
- Cấu trúc: `week01-pre-k8s/{apps/<app>,nginx,db,terraform,ansible}`, report ở `reports/YYYY-MM-DD.md`.
- Không commit secret, `*.tfstate`, `.env` (đã có `.gitignore`). Dùng `.env.example`.
- Report hằng ngày cho mentor: 3 mục Done / Next / Issues, vài gạch đầu dòng ngắn.
