data "aws_caller_identity" "this" {}

resource "aws_s3_bucket" "this" {
  bucket = "${data.aws_caller_identity.this.account_id}-${var.service_name}-static-files"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOACRead"
        Effect = "Allow"
        Principal = {
          "Service" : "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" : "arn:aws:cloudfront::${data.aws_caller_identity.this.account_id}:distribution/${var.cloudfront_distribution_id}"
          }
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.this.id}/*"
      }
    ]
  })
}

locals {
  ssm_parameters = {
    static_files_bucket_name = aws_s3_bucket.this.id
  }
}

resource "aws_ssm_parameter" "ssm_parameters" {
  for_each = local.ssm_parameters

  name  = "/__deployment__/applications/${var.service_name}/${each.key}"
  type  = "String"
  value = each.value
}
