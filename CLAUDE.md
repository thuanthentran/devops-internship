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
  - `changes`: `dorny/paths-filter@v4` xuất mảng JSON các service đổi (`apps/api|web|java|rust|python/**`; sửa 2 file workflow thì build lại tất cả). Sửa Terraform/Ansible/tài liệu thì mảng rỗng, không build.
  - `build`: matrix từ mảng trên, gọi workflow tái sử dụng `build-image.yaml` với `push: ${{ github.event_name == 'push' }}`. Bị skip khi không service nào đổi.
  - `ci-ok`: `if: always()`, fail nếu có job `failure`/`cancelled`. Đây là **required check duy nhất** (đặt thẳng job build làm required sẽ làm PR chỉ sửa Terraform kẹt "pending").
- `.github/workflows/build-image.yaml` (`workflow_call`, input `app`, `push`, `version`): luôn `docker build` kèm nhãn OCI (`revision` = SHA đầy đủ, `source`, `created`); chỉ khi `push` và ref là `main` hoặc tag mới OIDC assume `github-actions-ecr`, login ECR, push `music-<app>:<TAG>`. `TAG` = `version` nếu có, không thì `<sha7>` (7 ký tự đầu của commit). Đọc nhãn: `docker pull` rồi `docker inspect <image> --format '{{ json .Config.Labels }}'` (`aws ecr describe-images` không hiện nhãn).
- Phát hành bản có số phiên bản (2026-11-23): tag git **theo từng service** `<app>/vX.Y.Z` (vd `python/v0.1.0`) kích hoạt `.github/workflows/release.yaml` (`parse` kiểm `app` thuộc `api|web|java|rust|python` và `X.Y.Z` đúng regex rồi mới gọi `build-image.yaml` với `version`, `push: true`). Image ECR chỉ mang tag `X.Y.Z` (không thêm `sha7`, vì tag IMMUTABLE và build lại ra digest khác). Đánh đổi: release **build lại** từ cùng commit nên digest khác bản `sha7`; khi deploy chọn một bản và ghim digest. Tra digest: `aws ecr describe-images --repository-name music-<app> --image-ids imageTag=<tag> --query 'imageDetails[0].imageDigest' --output text`. Terraform: `github_subjects` có thêm `repo:...:ref:refs/tags/*/v*` (đã apply). Ruleset tag `tagging` (GitHub) cho `*/v*`: restrict updates/deletions, block force push, bypass list trống, không restrict creations; tag đã phát hành không xoá/dời được (muốn sửa phải tạm Disabled ruleset). `release.yaml` chỉ chạy được khi file đã nằm trên commit được tag. Đã thử `python/v0.1.0`: ECR có tag `0.1.0`, `revision` trùng commit.
- Dockerfile (2026-11-23): api dùng `npm ci --omit=dev` với `package-lock.json` (sửa `package.json` ngoài dependency không làm `npm ci` lỗi; chỉ lệch dependency mới lỗi). Node bắt SIGTERM/SIGINT để tắt êm (`server.close` + `pool.end`, timer 8s `.unref()`; stop 10,3s/exit 137 giảm còn 0,29s/exit 0). Java (Spring Boot) và Python và Postgres vốn đã tắt êm. Rust CI luôn chậm vì runner mới không có cache; sẽ thử `cache-from/cache-to: type=gha` ở PR riêng. Khi viết Deployment K8s cần thêm xử lý SIGTERM/readiness (preStop, /health trả 503).
- `concurrency` chỉ huỷ lần chạy cũ với `pull_request`. Không dùng `[skip ci]` trên nhánh PR (check bắt buộc sẽ kẹt pending).
- Ruleset `ci-checkin` (mặc định = `main`): cần PR, approvals = 0 (repo một người), required check `ci-ok`, block force push, restrict deletions, require code scanning results (CodeQL, High+). "Require code quality results" để tắt cho tới khi bật Code Quality.
- CodeQL default setup: GitHub Actions + Java/Kotlin + JavaScript/TypeScript + Python + Rust (Python/Rust do GitHub tự thêm khi phát hiện trên `main`), query suite Extended; chạy khi push/PR vào `main` và hằng tuần. Là check riêng, không nằm trong `ci-ok`.
- ECR hiện có 5 repo: `music-api`, `music-web`, `music-java`, `music-rust`, `music-python` (`var.repositories` trong `terraform/variables.tf`; policy IAM tự theo `for_each`). Merge PR #1 (`f67510c`) đã push 3 image tag `f67510c...`.
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
  - Thiết kế: mỗi backend một chức năng riêng (không phải bản sao của Node). Frontend gọi **một origin**; nginx ngoài rẽ theo **tài nguyên** (`/api/playlists` → Java, `/api/songs` → Rust, còn lại → `web`/Node), **không rewrite**: `proxy_pass http://svc:port;` (không `/` cuối) và chính service khai báo đúng đường dẫn công khai trong code (best practice: URL công khai là hợp đồng với frontend, đặt theo tài nguyên, không theo ngôn ngữ/tên service như `/api/java/`). Không cần CORS, subdomain hay cert mới. Giống Ingress/HTTPRoute path-prefix ở K8s. Ba nơi phải khớp: frontend gọi, `location` nginx, mapping trong backend. Thay dần kiểu strangler: thêm route ở service mới, kiểm tra, rồi mới xoá khỏi service cũ.
  - Bộ tối thiểu: Node (danh mục, đã có) + **Spring Boot** (playlist, đọc) + **Rust** (tra bài hát `GET /api/songs`, Redis cache-aside đứng giữa Rust và Postgres; app chỉ tra cứu, không có logic đếm lượt nghe) + Postgres + Redis. **Python** quay lại để có image cho bước K8s (chức năng chưa chốt, ví dụ thống kê hoặc gợi ý). Go bỏ. Rails/PHP/Quarkus/MongoDB/DynamoDB là bonus.
  - Thứ tự: Java trước (nặng nhất, đo RAM bằng `docker stats`, đặt `mem_limit` + `MaxRAMPercentage`), rồi Rust + Redis, cuối cùng sửa frontend (các khung) và nginx.
  - Java/Rust build bằng GitHub Actions (dev box 2GB không build được). EC2 `c7i-flex.large` 4GB, còn RAM trống đáng kể trước khi sang RKE2.
  - [x] Java (Spring Boot 4.1, Java 21, Maven, `apps/java`, cổng 8080): `PlaylistController` phục vụ `GET /api/playlists` và `GET /api/playlists/{id}` (404 bằng `ResponseStatusException`), Dockerfile multi-stage (user `spring`, `-DskipTests`, `MaxRAMPercentage=70`), repo ECR `music-java`, CI build/push theo service. Đã thử trên dev box (kéo image ECR, `docker run` nối mạng compose) rồi deploy lên EC2.
    - Prod: service `java` trong `docker-compose.prod.yml` (image theo digest, `mem_limit: 512m`, healthcheck `127.0.0.1:8080/actuator/health` `start_period: 30s`, không `ports`; `nginx` `depends_on` java healthy). Nginx khối 443 của `app.`: `location /api/playlists { proxy_pass http://java:8080; }` (khớp tiền tố dài nhất nên thắng `location /`; không rewrite).
    - **Java đã thay hẳn route playlist của Node**: đã xoá `/api/playlists` khỏi `apps/api` (sau đó Node cũng gỡ `/api/songs` cho Rust; Node chỉ còn `/health`, `/api/artists`, `/api/genres`). Kiểm tra: `app.../api/playlists` do Java trả (log Java có Hikari kết nối DB), `node.../api/playlists` trả 404 của Express; JSON `/api/playlists/1` của hai bản trước khi gỡ giống hệt (`diff`). Frontend (`App.jsx`) không phải sửa vì gọi đúng `/api/playlists`.
    - RAM trên EC2 (`docker stats`): Java ~136–147MiB/512MiB, Node ~20–89MiB, Postgres ~69MiB, nginx ~12MiB, web ~10MiB (tổng ~320MiB / 3,7GiB). Còn dư nhiều cho Rust + Redis.
    - Quy trình đổi image prod: merge PR → CI push `music-<app>:<SHA>` → `aws ecr describe-images ... --query 'sort_by(imageDetails,&imagePushedAt)[-1]'` lấy digest → sửa `image:` trong compose prod → Ansible. Deploy nginx và image mới cùng một lần để tránh 404. Chạy Ansible cần EC2 đang chạy; kiểm tra Docker trên EC2: `ssh -i ~/.ssh/music-ec2 ubuntu@<private_ip>` rồi `cd /home/ubuntu/music && docker compose ps`.
    - Còn sót: dòng comment `//trigger ci builds` cuối `PlaylistController.java` (dùng để thử CI; xoá sẽ kích hoạt build Java).
  - [x] Rust + Redis (`apps/rust`, axum 0.7 + sqlx 0.8 + redis 0.27, cổng 8080): `GET /api/songs`, `GET /api/songs/{id}` (404 khi không có), `GET /health`. Dùng lại đúng `SONG_SELECT` của Node nên JSON giống hệt (`diff` hai bản báo giống). Cache-aside trong Redis: key `songs:all` và `songs:<id>`, TTL 60s, lưu sẵn chuỗi JSON; Redis lỗi thì coi như miss và đọc Postgres (`ConnectionManager` tự nối lại); log `cache hit/miss` (Rust/axum không có access log mặc định, xem status ở log nginx). Bắt SIGTERM để tắt êm.
    - Dockerfile multi-stage: build dependency riêng để cache layer, chạy trên `debian:bookworm-slim` kèm `curl` cho healthcheck (không có `wget`), user không root. Chỉ build bằng CI; dev box chỉ chạy `cargo check` trong container giới hạn RAM. `Cargo.lock` commit vào git, dùng `--locked`.
    - Prod: service `redis` (`redis:8-alpine`, `mem_limit: 64m`, `--maxmemory 48mb`, `allkeys-lru`, `--save ""` vì chỉ là cache, không publish port) và `rust` (image theo digest, healthcheck `curl 127.0.0.1:8080/health`, env `POSTGRES_*`, `REDIS_URL=redis://redis:6379`); nginx `depends_on` rust healthy, `location /api/songs { proxy_pass http://rust:8080; }`. Repo ECR `music-rust`, filter `rust` trong `ci.yaml`.
    - Đã thay hẳn route songs của Node theo kiểu strangler: deploy Rust, `diff` JSON, rồi gỡ khỏi `apps/api` và cập nhật digest `api`. Kết quả: `node.../api/songs` 404, `app.../api/songs` 200 (Rust), `/api/playlists` vẫn Java, `/api/artists` vẫn Node.
    - RAM trên EC2 (`docker stats`, sau 200 request `/api/songs`): Rust ~1,2MiB (`mem_limit: 64m`), Redis ~6,2MiB (`mem_limit: 64m`), Java ~152MiB/512MiB, Node ~19MiB, Postgres ~71MiB, nginx ~13MiB, web ~10MiB (tổng ~273MiB / 3,7GiB). Rust nhẹ hơn Java ~100 lần; không có JVM nên không cần cấp heap trước.
    - Lưu ý: sửa `ci.yaml` làm cả 4 filter khớp nên merge build/push cả 4 image (digest `api`/`web`/`java` đổi dù code không đổi; compose prod vẫn ghim digest cũ nên không ảnh hưởng). `terraform apply` tạo repo `music-rust` phải xong trước khi merge. Chạy `docker compose` trên EC2 phải ở `/home/ubuntu/music`. Compose dev chưa có Rust/Redis nên `/api/songs` ở dev trả 404.
  - [x] Thống kê nginx + giới hạn log (2026-11-18): `scripts/nginx-stats.sh` (đọc `docker compose logs --since 24h nginx`, top 10 IP/endpoint/status, ghi `/home/ubuntu/reports/nginx-YYYY-MM-DD.txt`); Ansible tạo thư mục, copy script và cron 00:05 (tên cron `Nginx logging`, giờ EC2 là UTC). `docker-compose.prod.yml` có `x-logging` (json-file, `max-size 10m`, `max-file "5"`) cho cả 7 service. `$remote_addr` đã kiểm tra là IP thật. Lưu ý: Ansible `--check` bỏ qua task `shell` nên không đăng nhập ECR, token 12h hết hạn thì `docker_compose_v2` báo 403 (chạy thật thì không lỗi); đổi `logging` tạo lại container.
  - [x] Backup Postgres cách A (2026-11-18): `scripts/postgres-backup.sh` (`docker compose exec -T postgres sh -c 'pg_dumpall -U "${POSTGRES_USER}"' | gzip`, ghi `.tmp` rồi `gzip -t` rồi `mv`, giữ 7 ngày bằng `find -mtime +7`, `umask 077`) vào `/home/ubuntu/backups` (0700); Ansible tạo thư mục, copy script (0750) và cron `Postgres backup` 00:06 UTC. Đã chạy tay và **restore thử** vào container `postgres:18-alpine` tạm: số dòng khớp prod (6 nghệ sĩ, 11 bài, 3 playlist, 11 playlist_songs). Lưu ý: `cmd1 && echo` làm `set -e` không dừng khi `cmd1` fail; cron chạy ở `$HOME` nên script phải `cd`; image alpine không có `bash`. Quyền thư mục/script đổi 0755 sang 0750 theo SonarCloud (hotspot). Còn: xác nhận cron tự chạy, thử xoá file cũ >7 ngày.
  - [x] Backup lên S3 (2026-11-18, `terraform/s3_backup.tf`): bucket `music-backup-bucket-380085` (chặn public, SSE-S3 `AES256`, versioning, lifecycle xoá `postgres/` sau 5 ngày). Role `music-ec2-role` chỉ có `s3:PutObject` trên `postgres/*` và `s3:ListBucket` (cố ý không có `DeleteObject`/`GetObject`, nên EC2 bị chiếm cũng không xoá/đọc được backup). `postgres-backup.sh` upload bằng `aws s3 cp` sau khi verify và trước khi xoá bản local cũ; `AWS_DEFAULT_REGION` đặt trong script cho cron. Đã restore thử từ S3 trên dev box (EC2 không đọc được, đúng thiết kế): số dòng khớp. Lưu ý: `kms_master_key_id` không đi cùng `AES256`; ARN `ListBucket` không có `/*`, `PutObject` có; statement quyền nằm trong policy permission chứ không phải trust. `tfplan` đã vào `.gitignore`. Còn: xác nhận cron tự chạy (local + S3), cân nhắc tăng retention S3 lên 30 ngày.
  - [ ] Backup cách B (tuỳ chọn, chưa làm): Terraform DLM `aws_dlm_lifecycle_policy` snapshot EBS
  - [x] Python (`apps/python`, FastAPI + psycopg 3 pool, SQL thuần, cổng 8080): `GET /api/stats` (tổng số bài/nghệ sĩ/playlist, bài theo thể loại, top 3 nghệ sĩ, tổng thời lượng playlist) và `GET /health`; chỉ đọc Postgres, không Redis. Dockerfile `python:3.13-slim`, user `fastapi`, dependency ghim bản; RAM ~39MiB nên `mem_limit: 128m`; healthcheck `python -c urllib` (slim không có curl/wget). Đã có: repo ECR `music-python` (đã apply), filter CI, service compose prod, nginx `location /api/stats` + `depends_on`. **Đã deploy lên EC2 (2026-11-19)**: image `music-python@sha256:b66463aa219425606438241e1adf744856ad8b9583a30497bec6074eaf9f2960` (tag `2f363240...`) điền vào compose prod, chạy Ansible; `app.../api/stats` 200 với số liệu khớp seed, `/api/playlists` (Java), `/api/songs` (Rust), `node.../api/artists` không đổi, `node.../api/stats` 404 (đúng). RAM EC2: Python 39,4MiB/128MiB, Java ~183MiB/512MiB, Rust ~17,5MiB/64MiB, Redis ~30,8MiB/64MiB, Postgres ~48MiB, Node ~17MiB, nginx ~12MiB, web ~10MiB (tổng ~360MiB / 3,7GiB).
  - [x] Sửa CI `web`: thiếu lockfile nên `npm install` kéo rollup 4.68.6 (lỗi "Code is nested too deeply" ở `react-dom/client.js`); thêm `package-lock.json` (rollup 4.68.5) và dùng `npm ci`.
  - [x] Sự cố CI push ECR 403 và ghim AMI (2026-11-19): sau merge PR #19, `docker push` đẩy hết layer rồi lỗi `HEAD .../manifests/... 403` ở cả 5 service vì policy `push_ecr` của role `github-actions-ecr` thiếu `ecr:BatchGetImage` (docker mới HEAD manifest trước `PutImage`). Sửa trong `ecr.tf`, đã `terraform apply` (PR #20). Cùng lúc `terraform plan` đòi **thay EC2** vì `data.aws_ami` dùng `most_recent` nên nhặt bản Ubuntu mới của Canonical (20261118): đã ghim AMI `var.ami_id = ami-063d94c44d4eba6e0` (bản 20261108) và tên trong data source; plan chỉ còn 1 thay đổi IAM. Bài học: không apply plan có `must be replaced`/destroy khi chưa đọc; sửa Terraform (hay tài liệu) không kích hoạt build, nên muốn push lại image phải sửa file trong `apps/<app>/**` (đã dùng commit `chore: trigger python build`, PR #21) hoặc Re-run failed jobs của run cũ.
  - Lưu ý CI/CodeQL: CodeQL chạy 2 lần mỗi PR (quét PR để thoả ruleset, rồi quét lại `main` sau merge) và là check riêng ngoài `ci-ok`. Default setup không lọc được theo path; có thể giảm thời gian bằng cách đổi query suite Extended sang Default hoặc bỏ bớt ngôn ngữ (giữ Rust vì là service thật). Chưa đổi.
  - Cron backup/stats **chưa xác nhận tự chạy**: EC2 bị stop ban đêm (boot 01:56 UTC ngày 19/11, sau 00:05/00:06 UTC) nên không có `nginx-2026-11-19.txt` hay backup mới; cron certbot 03:17 vẫn chạy được (cron daemon ổn). Cần để EC2 chạy qua 00:05 UTC để kiểm tra, hoặc chạy tay hai script. Trên S3 mới có 1 object (`20261118_071742`): bản `042221` (local) có trước khi script có bước upload.
  - [~] Frontend nhiều khung: **bỏ** (2026-11-18, người dùng chọn giữ kiến trúc hiện tại: mỗi backend độc lập cùng DB, nginx route theo tài nguyên). Tuỳ chọn: thêm một khung "thống kê" gọi `/api/stats`.

## Việc học thêm tuần 1 (todo, thứ tự đã thống nhất)
- [x] Khảo sát tfstate (5.1–5.3), CMD/ENTRYPOINT + layer (nhóm 2), lockfile, SIGTERM, `.dockerignore`.
- [x] Nhóm 1: image tag (`sha7`, semver theo service, nhãn OCI, tag ruleset).
- [ ] 1.3b drift `deliver-instance` (SG `k8s_nodes` + ổ 40GB): code đã sửa cho khớp (commit `a8b6ef6`, `plan` = No changes), chờ merge PR. Nợ nhỏ: kiểm tra lifecycle ECR "giữ 10 image" có đếm manifest không tag (attestation) hay không.
- [ ] Nhóm 3: Dockerfile Postgres (bake schema/seed) + migration (Flyway/dbmate, expand/contract).
- [ ] Nhóm 4: Docker networks frontend/backend (`internal: true`).
- [ ] 5.2/5.4/5.5: drift lab, S3 remote backend `use_lockfile`, thử lock.
- [ ] Nhóm 6: CD (SSM Run Command qua OIDC, biến digest thay vì sửa compose, approval, rollback).
- [ ] Nhóm 7: Monitoring (Prometheus/Grafana/exporters/Alertmanager).
- [ ] PR riêng: 2.4 cache build CI (`type=gha`), 2.6 so sánh kích thước image, bỏ curl khỏi Rust (`--healthcheck`), ghim base image.

## Quy ước
- Cấu trúc: `week01-pre-k8s/{apps/<app>,nginx,db,terraform,ansible}`, report ở `reports/YYYY-MM-DD.md`.
- Không commit secret, `*.tfstate`, `.env` (đã có `.gitignore`). Dùng `.env.example`.
- Report hằng ngày cho mentor: 3 mục Done / Next / Issues, vài gạch đầu dòng ngắn.
- Cách làm việc: người dùng tự viết file, Claude review/giải thích; chỉ sửa hộ khi được yêu cầu. Không commit/push/`terraform apply`/stop-start instance khi chưa được đồng ý. Commit/PR không kèm Co-Authored-By hay "Generated with Claude Code".
- Nhánh làm việc mới tạo từ `main` mới nhất sau mỗi PR được merge (nhánh `week01/node-api-react` đã dùng xong). Chỉ phần `apps/<app>/**` đổi mới kích hoạt build; nhớ stop EC2 khi không dùng.