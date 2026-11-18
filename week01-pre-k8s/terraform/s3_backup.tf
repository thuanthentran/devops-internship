resource "aws_s3_bucket" "music_backup_bucket" {
  bucket = var.backup_bucket
  tags = {
    Name        = "music backup bucket"
    Environment = "prod"
  }
}



resource "aws_s3_bucket_public_access_block" "music_access_block" {
  bucket = aws_s3_bucket.music_backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "music_encryption" {
  bucket = aws_s3_bucket.music_backup_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "music_versioning" {
  bucket = aws_s3_bucket.music_backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "music_lifecycle" {
  bucket = aws_s3_bucket.music_backup_bucket.id

  rule {
    id = "rule-1"
    filter {
      prefix = "postgres/"
    }
    expiration {
      days = 5
    }
    noncurrent_version_expiration {
      noncurrent_days = 5
    }
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket_versioning.music_versioning]
}
