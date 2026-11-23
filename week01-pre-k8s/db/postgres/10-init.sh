#!/bin/sh
# Chạy bởi entrypoint của Postgres khi data dir còn trống (server tạm, chỉ nghe unix socket).
set -e

# 1. Schema do dbmate tạo, nên bảng schema_migrations đúng sẵn (dùng chung nguồn với prod).
dbmate \
  --url "postgres://${POSTGRES_USER}@/${POSTGRES_DB}?host=/var/run/postgresql&sslmode=disable" \
  --migrations-dir /migrations \
  --no-dump-schema \
  up

# 2. Dữ liệu mẫu.
psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /seed/02-seed.sql
