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
  Route53 subdomain. Tên miền: `thenttthytlu.io.vn` (đã có; định ủy quyền một subdomain sang Route53).
- CI: GitHub Actions build → ECR, đăng nhập bằng OIDC role `github-actions-ecr` (không static key).
- Terraform tạo hạ tầng; Ansible cấu hình + deploy lại (sau khi bản user_data chạy được).

## Thứ tự làm
1. Schema + seed Postgres
2. Node API + React, chạy bằng docker compose trên dev box
3. Terraform: OIDC provider + role + ECR repos; workflow `.github/workflows/build-push-ecr.yml`
4. Terraform EC2 lớn + nginx
5. Route53 + certbot
6. Thêm ngôn ngữ / DB phụ

## Tiến độ
- [x] 1. Schema + seed Postgres (`week01-pre-k8s/db/postgres`, 6 nghệ sĩ/11 bài/3 playlist). Script init chỉ chạy khi volume trống: sửa schema/seed phải `docker compose down -v`.
- [x] 2. Node API (`apps/api`, Express + pg, cổng 3000) + React/Vite (`apps/web`, nginx cổng 8080 proxy `/api` sang API), chạy bằng `docker compose up -d --build` trong `week01-pre-k8s/`. Cổng chỉ bind 127.0.0.1.
- [x] 3. Terraform OIDC + ECR + workflow build-push-ecr
  - [x] ECR repos `music-api`, `music-web` (`week01-pre-k8s/terraform`, tag IMMUTABLE, giữ 10 image, đã apply và push thử `music-api:v1`). State local, `terraform.tfstate` không commit.
  - [x] OIDC provider + role `github-actions-ecr` (đã apply; chỉ nhánh `main` và `week01/*` của repo này được assume; role chỉ có quyền push vào 2 repo ECR). Terraform chia file: `providers.tf`, `ecr.tf`, `github-oidc.tf`.
  - [x] Workflow `.github/workflows/github-action.yaml` (matrix api/web, OIDC, push ECR tag = commit SHA; đã chạy xanh). Lưu ý: claim `sub` của GitHub có ID bất biến (`repo:owner@id/repo@id:ref:...`), xem `github_subjects`.
- [x] 4. Terraform EC2 + deploy (nginx front proxy làm ở bước 5 cùng certbot) (`c7i-flex.large`; domain đã có)
  - [x] Security group `music-web` (80/443 public, SSH chỉ từ SG dev box) — đã apply.
  - [x] IAM role `music-ec2-role` + instance profile `music-ec2` (pull ECR) — đã apply (`ec2-iam.tf`).
  - [x] EC2 `deliver-instance` (`aws_instance.tf`, module ec2-instance, Ubuntu 24.04, `c7i-flex.large`, 20GB gp3, IMDSv2, key `music-ec2` ở `~/.ssh/music-ec2`) — đã apply; user_data cài Docker + compose + aws-cli. Đã kiểm tra pull ECR bằng role. SSH chỉ qua IP private (rule SG nguồn là SG dev box).
  - [x] Compose prod (`docker-compose.prod.yml`, image từ ECR theo digest; cổng 80/443 do nginx publish, xem bước 5) + Ansible (`week01-pre-k8s/ansible/`: `inventory.ini`, `deploy.yaml`). Deploy: `cd week01-pre-k8s/ansible && ansible-playbook -i inventory.ini deploy.yaml`. Đã chạy, `curl http://<public_ip>/api/artists` OK. IP public đổi khi stop/start; Ansible dùng IP private (`terraform output private_ip`).

- [x] 5. Route53 + certbot
  - [x] Elastic IP `aws_eip.this` gắn `deliver-instance` (IP cố định, không đổi khi stop/start).
  - [x] Hosted zone `lab.thenttthytlu.io.vn` (`route53.tf`, biến `domain`); đã ủy quyền: 4 bản ghi NS `lab` ở nhà đăng ký trỏ về 4 name server của zone (`terraform output name_servers`). `terraform destroy` sẽ làm đổi bộ NS, phải cập nhật lại ở nhà đăng ký.
  - [x] Bản ghi A `app.lab...` và `node.lab...` trỏ vào EIP (đã kiểm tra bằng `dig`).
  - [x] Nginx front proxy (container `nginx:1.28-alpine`, `week01-pre-k8s/nginx/conf.d/default.conf`) route theo Host: `app.` tới `web:8080`, `node.` tới `api:3000`. Chỉ nginx publish 80/443; `web` đã bỏ `ports`. `web` cần healthcheck dùng `127.0.0.1` (không dùng `localhost`: Alpine phân giải ra IPv6 `::1` mà nginx chỉ nghe IPv4).
  - [x] Certbot (container, `profiles: ["tools"]`, webroot): đã cấp chứng chỉ thật Let's Encrypt cho `app.` và `node.` (một chứng chỉ chung, file ở `/etc/letsencrypt/live/app.lab.thenttthytlu.io.vn/`, hết hạn 2027-02-14). Nginx có 443 + redirect 301 từ 80; `/.well-known/` giữ ở khối cổng 80. Chạy certbot trên EC2 trong `/home/ubuntu/music` (`docker compose run --rm -T certbot ...`), không chạy trên dev box.
  - [x] Gia hạn: cron của user `ubuntu` (03:17 hằng ngày) chạy `certbot renew` rồi `nginx -s reload`, cài qua Ansible; handler `Reload nginx` chạy khi config nginx đổi. Đã thử `renew --dry-run` thành công (certbot tự chờ ngẫu nhiên vài phút khi không có TTY; thêm `--no-random-sleep-on-renew` khi chạy tay).

- [ ] 6. Thêm ngôn ngữ / DB phụ (python, go, php, spring, quarkus, rails; MySQL, MongoDB, Redis, DynamoDB)

## Quy ước
- Cấu trúc: `week01-pre-k8s/{apps/<app>,nginx,db,terraform,ansible}`, report ở `reports/YYYY-MM-DD.md`.
- Không commit secret, `*.tfstate`, `.env` (đã có `.gitignore`). Dùng `.env.example`.
- Report hằng ngày cho mentor: 3 mục Done / Next / Issues, vài gạch đầu dòng ngắn.
