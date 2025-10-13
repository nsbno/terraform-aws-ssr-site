# Managed cache policies
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

locals {
  alb_origin_id          = "${var.service_name}-alb-origin"
  alternate_domain_names = var.enable_wildcard_domain ? concat(["*.${var.domain_name}"], var.additional_domain_names) : var.additional_domain_names
  all_domain_names       = concat([var.domain_name], local.alternate_domain_names)
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.service_name
  description                       = "OAC for ${var.service_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_s3_bucket" "static_files" {
  bucket = var.external_s3_bucket_id != "" ? var.external_s3_bucket_id : aws_s3_bucket.this[0].id
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled
  comment         = "${var.service_name} distribution"

  aliases             = local.all_domain_names
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment

  origin {
    domain_name = var.alb_domain_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = data.aws_s3_bucket.static_files.bucket_regional_domain_name
    origin_id                = var.s3_bucket_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id = local.alb_origin_id

    # Use the cache policy from the variable or fallback to caching disabled
    cache_policy_id = try(var.default_cache_behavior.cache_policy_id, data.aws_cloudfront_cache_policy.caching_disabled.id)
    allowed_methods = try(var.default_cache_behavior.allowed_methods, ["GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT", "DELETE"])
    cached_methods  = try(var.default_cache_behavior.cached_methods, ["GET", "HEAD"])

    origin_request_policy_id = try(var.default_cache_behavior.origin_request_policy_id, data.aws_cloudfront_origin_request_policy.all_viewer.id)

    viewer_protocol_policy = try(var.default_cache_behavior.viewer_protocol_policy, "redirect-to-https")
    compress               = try(var.default_cache_behavior.compress, true)

    dynamic "lambda_function_association" {
      for_each = var.preview_url_mapper_lambda_arn != "" ? [1] : []

      content {
        event_type = "origin-request"
        lambda_arn = var.preview_url_mapper_lambda_arn
      }
    }
  }

  # Static assets cache behavior
  dynamic "ordered_cache_behavior" {
    for_each = var.s3_cache_path_pattern
    iterator = iter

    content {
      path_pattern     = iter.value
      target_origin_id = data.aws_s3_bucket.static_files.id

      # Use the cache policy from the variable or fallback to caching optimized
      cache_policy_id = try(var.ordered_cache_behavior.cache_policy_id, data.aws_cloudfront_cache_policy.caching_optimized.id)

      allowed_methods = try(var.ordered_cache_behavior.allowed_methods, ["GET", "HEAD", "OPTIONS"])
      cached_methods  = try(var.ordered_cache_behavior.cached_methods, ["GET", "HEAD"])

      origin_request_policy_id = try(var.ordered_cache_behavior.origin_request_policy_id, null)
      viewer_protocol_policy   = try(var.ordered_cache_behavior.viewer_protocol_policy, "redirect-to-https")
      compress                 = try(var.ordered_cache_behavior.compress, true)
    }

  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront.arn
    minimum_protocol_version = var.minimum_protocol_version
    ssl_support_method       = var.ssl_support_method
  }

  restrictions {
    dynamic "geo_restriction" {
      for_each = [var.geo_restriction]

      content {
        restriction_type = lookup(geo_restriction.value, "restriction_type", "none")
        locations        = lookup(geo_restriction.value, "locations", [])
      }
    }
  }
}

resource "aws_route53_record" "cloudfront_alias" {
  for_each = toset(local.all_domain_names)

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = local.alternate_domain_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation for the certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = var.route53_hosted_zone_id
  records         = [each.value.record]
  ttl             = 60

  depends_on = [aws_acm_certificate.cloudfront]
}

# Certificate validation
resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = var.certificate_validation_timeout
  }
}

# For the Pipeline to use the CloudFront domain name
resource "aws_ssm_parameter" "for_pipeline" {
  name  = "/__deployment__/applications/${var.service_name}/cloudfront_domain_name"
  type  = "String"
  value = var.domain_name
}

# Add S3 bucket policy allowing CloudFront distribution
# Default create a static files bucket if no external bucket is provided
data "aws_caller_identity" "this" {}

resource "aws_s3_bucket" "this" {
  count = var.external_s3_bucket_id != "" ? 0 : 1

  bucket = "${data.aws_caller_identity.this.account_id}-${var.service_name}-static-files"
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.external_s3_bucket_id != "" ? 0 : 1

  bucket = data.aws_s3_bucket.static_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "for_cloudfront" {
  count = var.external_s3_bucket_id != "" ? 0 : 1

  bucket = data.aws_s3_bucket.static_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          "Service" : "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" : "arn:aws:cloudfront::${data.aws_caller_identity.this.account_id}:distribution/${aws_cloudfront_distribution.this.id}"
          }
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${data.aws_s3_bucket.static_files.id}/*"
      }
    ]
  })
}

# Needed for the deployment pipeline to know which bucket to upload static files to for SSR sites
resource "aws_ssm_parameter" "bucket_name" {
  name  = "/__deployment__/applications/${var.service_name}/static_files_bucket_name"
  type  = "String"
  value = data.aws_s3_bucket.static_files.id

  # overwrite, in case a external bucket is already configured with this parameter
  overwrite = true
}
