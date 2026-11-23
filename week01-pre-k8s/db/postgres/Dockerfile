# Image Postgres cho dev/CI: lần khởi tạo đầu (volume trống) tự áp dụng migration rồi nạp seed.
# Build context là thư mục db/ (xem build-image.yaml): docker build -f db/postgres/Dockerfile db/
# Prod KHÔNG dùng image này làm nguồn schema: prod giữ dữ liệu trong volume và chạy dbmate riêng.
FROM ghcr.io/amacneil/dbmate:2 AS dbmate

FROM postgres:18-alpine
COPY --from=dbmate /usr/local/bin/dbmate /usr/local/bin/dbmate
COPY migrations /migrations
COPY seed/02-seed.sql /seed/02-seed.sql
COPY --chmod=755 postgres/10-init.sh /docker-entrypoint-initdb.d/10-init.sh
