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
  - [x] Workflow ban đầu `github-action.yaml` đã được thay bằng CI mới (xem mục "CI" bên dưới). Lưu ý: claim `sub` của GitHub có ID bất biến (`repo:owner@id/repo@id:ref:...`), xem `github_subjects`. PR không assume được role (sub của PR khác), nên PR chỉ build, không chạm AWS.

### CI (GitHub Actions) và bảo vệ nhánh `main`
- `.github/workflows/ci.yaml` (chạy khi `pull_request` và `push` vào `main`), 3 job:
  - `changes`: `dorny/paths-filter@v4` xuất mảng JSON các service đổi (`apps/api|web|java/**`; sửa 2 file workflow thì build lại tất cả). Sửa Terraform/Ansible/tài liệu thì mảng rỗng, không build.
  - `build`: matrix từ mảng trên, gọi workflow tái sử dụng `build-image.yaml` với `push: ${{ github.event_name == 'push' }}`. Bị skip khi không service nào đổi.
  - `ci-ok`: `if: always()`, fail nếu có job `failure`/`cancelled`. Đây là **required check duy nhất** (đặt thẳng job build làm required sẽ làm PR chỉ sửa Terraform kẹt "pending").
- `.github/workflows/build-image.yaml` (`workflow_call`, input `app`, `push`): luôn `docker build`; chỉ khi `push && ref == main` mới OIDC assume `github-actions-ecr`, login ECR, push `music-<app>:<commit SHA>`.
- `concurrency` chỉ huỷ lần chạy cũ với `pull_request`. Không dùng `[skip ci]` trên nhánh PR (check bắt buộc sẽ kẹt pending).
- Ruleset `ci-checkin` (mặc định = `main`): cần PR, approvals = 0 (repo một người), required check `ci-ok`, block force push, restrict deletions, require code scanning results (CodeQL, High+). "Require code quality results" để tắt cho tới khi bật Code Quality.
- CodeQL default setup: GitHub Actions + Java/Kotlin + JavaScript/TypeScript, chạy khi push/PR vào `main` và hằng tuần. Là check riêng, không nằm trong `ci-ok`.
- ECR hiện có 3 repo: `music-api`, `music-web`, `music-java` (`var.repositories` trong `terraform/variables.tf`; policy IAM tự theo `for_each`). Merge PR #1 (`f67510c`) đã push 3 image tag `f67510c...`.
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

- [ ] 6. Microservices polyglot: 1 frontend gọi nhiều backend cùng lúc, hiển thị theo từng góc màn hình (làm theo từng lát, mỗi service đi hết: app, ECR repo, CI matrix, compose prod, nginx, deploy)
  - Thiết kế: mỗi backend một chức năng riêng (không phải bản sao của Node). Frontend gọi **một origin**; nginx ngoài rẽ theo **tài nguyên** (`/api/playlists` → Java, `/api/listens` → Rust, còn lại → `web`/Node), **không rewrite**: `proxy_pass http://svc:port;` (không `/` cuối) và chính service khai báo đúng đường dẫn công khai trong code (best practice: URL công khai là hợp đồng với frontend, đặt theo tài nguyên, không theo ngôn ngữ/tên service như `/api/java/`). Không cần CORS, subdomain hay cert mới. Giống Ingress/HTTPRoute path-prefix ở K8s. Ba nơi phải khớp: frontend gọi, `location` nginx, mapping trong backend. Thay dần kiểu strangler: thêm route ở service mới, kiểm tra, rồi mới xoá khỏi service cũ.
  - Bộ tối thiểu: Node (danh mục, đã có) + **Spring Boot** (playlist, đọc) + **Rust** (lịch sử nghe, **ghi** `POST /listens`, Redis đếm lượt) + Postgres + Redis. Python/Go bỏ (người dùng đã biết). Rails/PHP/Quarkus/MongoDB/DynamoDB là bonus.
  - Thứ tự: Java trước (nặng nhất, đo RAM bằng `docker stats`, đặt `mem_limit` + `MaxRAMPercentage`), rồi Rust + Redis, cuối cùng sửa frontend (các khung) và nginx.
  - Java/Rust build bằng GitHub Actions (dev box 2GB không build được). EC2 `c7i-flex.large` 4GB, còn RAM trống đáng kể trước khi sang RKE2.
  - [x] Java (Spring Boot 4.1, Java 21, Maven, `apps/java`, cổng 8080): `PlaylistController` phục vụ `GET /api/playlists` và `GET /api/playlists/{id}` (404 bằng `ResponseStatusException`), Dockerfile multi-stage (user `spring`, `-DskipTests`, `MaxRAMPercentage=70`), repo ECR `music-java`, CI build/push theo service. Đã thử trên dev box (kéo image ECR, `docker run` nối mạng compose) rồi deploy lên EC2.
    - Prod: service `java` trong `docker-compose.prod.yml` (image theo digest, `mem_limit: 512m`, healthcheck `127.0.0.1:8080/actuator/health` `start_period: 30s`, không `ports`; `nginx` `depends_on` java healthy). Nginx khối 443 của `app.`: `location /api/playlists { proxy_pass http://java:8080; }` (khớp tiền tố dài nhất nên thắng `location /`; không rewrite).
    - **Java đã thay hẳn route playlist của Node**: đã xoá `/api/playlists` khỏi `apps/api` (Node còn `/health`, `/api/artists`, `/api/genres`, `/api/songs`). Kiểm tra: `app.../api/playlists` do Java trả (log Java có Hikari kết nối DB), `node.../api/playlists` trả 404 của Express; JSON `/api/playlists/1` của hai bản trước khi gỡ giống hệt (`diff`). Frontend (`App.jsx`) không phải sửa vì gọi đúng `/api/playlists`.
    - RAM trên EC2 (`docker stats`): Java ~136–147MiB/512MiB, Node ~20–89MiB, Postgres ~69MiB, nginx ~12MiB, web ~10MiB (tổng ~320MiB / 3,7GiB). Còn dư nhiều cho Rust + Redis.
    - Quy trình đổi image prod: merge PR → CI push `music-<app>:<SHA>` → `aws ecr describe-images ... --query 'sort_by(imageDetails,&imagePushedAt)[-1]'` lấy digest → sửa `image:` trong compose prod → Ansible. Deploy nginx và image mới cùng một lần để tránh 404. Chạy Ansible cần EC2 đang chạy; kiểm tra Docker trên EC2: `ssh -i ~/.ssh/music-ec2 ubuntu@<private_ip>` rồi `cd /home/ubuntu/music && docker compose ps`.
    - Còn sót: dòng comment `//trigger ci builds` cuối `PlaylistController.java` (dùng để thử CI; xoá sẽ kích hoạt build Java).
  - [ ] Rust + Redis (`apps/rust`)
  - [ ] Frontend nhiều khung + nginx path routing

## Quy ước
- Cấu trúc: `week01-pre-k8s/{apps/<app>,nginx,db,terraform,ansible}`, report ở `reports/YYYY-MM-DD.md`.
- Không commit secret, `*.tfstate`, `.env` (đã có `.gitignore`). Dùng `.env.example`.
- Report hằng ngày cho mentor: 3 mục Done / Next / Issues, vài gạch đầu dòng ngắn.
- Cách làm việc: người dùng tự viết file, Claude review/giải thích; chỉ sửa hộ khi được yêu cầu. Không commit/push/`terraform apply`/stop-start instance khi chưa được đồng ý. Commit/PR không kèm Co-Authored-By hay "Generated with Claude Code".
- Nhánh làm việc mới tạo từ `main` mới nhất sau mỗi PR được merge (nhánh `week01/node-api-react` đã dùng xong). Chỉ phần `apps/<app>/**` đổi mới kích hoạt build; nhớ stop EC2 khi không dùng.