#!/usr/bin/env bash
set -euo pipefail

export AWS_DEFAULT_REGION="ap-southeast-1"
umask 077

BACKUP_DIR="${HOME}/backups"
date_fmt="$(date +"%Y%m%d_%H%M%S")"
BACKUP_FILE="music.sql.gz"
S3_BUCKET="music-backup-bucket-380085"
file="${BACKUP_DIR}/${date_fmt}-${BACKUP_FILE}"

cd /home/ubuntu/music
docker compose exec -T postgres sh -c 'pg_dumpall -U "${POSTGRES_USER}"' | gzip > "${file}.tmp"
gzip -t "${file}.tmp"
echo "Backup verified successfully."

mv "${file}.tmp" "${file}"
aws s3 cp "$file" "s3://${S3_BUCKET}/postgres/"
echo "Uploaded to S3"
find "${BACKUP_DIR}" -mtime +7 -name '*.sql.gz' -delete
echo "Old backups deleted successfully."