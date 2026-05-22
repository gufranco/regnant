# Archive bucket. OTel Collector forwards logs and trace summaries
# here for long-term retention beyond what Loki and Tempo keep.

resource "aws_s3_bucket" "archive" {
  bucket = local.archive_bucket

  tags = merge(local.module_tags, {
    Name = local.archive_bucket
  })
}

resource "aws_s3_bucket_ownership_controls" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arns["s3"]
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    id     = "tiered-archival"
    status = "Enabled"

    filter {}

    transition {
      days          = var.archive_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.archive_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.archive_expire_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 60
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
