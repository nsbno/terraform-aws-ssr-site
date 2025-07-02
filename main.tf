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
  alb_origin_id = "${var.application_name}-alb-origin"
  s3_origin_id  = "${var.application_name}-s3-origin"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled
  comment         = "${var.application_name} distribution"

  aliases             = var.enable_wildcard_domain ? ["*.${var.domain_name}", var.domain_name] : [var.domain_name]
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
    domain_name = var.s3_website_endpoint
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # S3 website endpoints only support HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
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
  }

  # Static assets cache behavior
  dynamic "ordered_cache_behavior" {
    for_each = var.s3_cache_path_pattern
    iterator = iter

    content {
      path_pattern     = iter.value
      target_origin_id = local.s3_origin_id

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
  for_each = var.enable_wildcard_domain ? toset([var.domain_name, "*.${var.domain_name}"]) : [var.domain_name]

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
  provider                  = aws.certificate_provider
  domain_name               = var.domain_name
  subject_alternative_names = var.enable_wildcard_domain ? ["*.${var.domain_name}"] : []
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
  provider                = aws.certificate_provider
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = var.certificate_validation_timeout
  }
}
