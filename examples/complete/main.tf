# Provider for us-east-1 (required for CloudFront certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      application = "application_name"
    }
  }
}

locals {
  application_name = "infrademo-demo-app"
  domain_name      = "petstore.infrademo.vydev.io"
  alb_domain_name  = "lb.infrademo.vydev.io"
}


module "metadata" {
  source = "github.com/nsbno/terraform-aws-account-metadata?ref=x.y.z"
}

module "cloudfront_only" {
  source = "../../terraform-aws-cloudfront"

  providers = {
    aws.certificate_provider = aws.us_east_1
  }

  application_name = local.application_name
  domain_name      = local.domain_name
  alb_domain_name  = local.alb_domain_name

  route53_hosted_zone_id = module.metadata.dns.hosted_zone_id

  s3_website_endpoint   = aws_s3_bucket_website_configuration.this.website_endpoint
  s3_cache_path_pattern = ["/assets/*", "/favicon.ico"]
}


# S3 Bucket for static files
data "aws_caller_identity" "this" {}

resource "aws_s3_bucket" "this" {
  bucket = "${data.aws_caller_identity.this.account_id}-${local.application_name}-static-files"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.this.id}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = "index.html"
  }
}
