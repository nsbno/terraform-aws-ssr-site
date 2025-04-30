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

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled
  comment         = "${var.application_name} distribution"

  # Domain
  aliases             = [var.domain_name]
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment

  dynamic "origin" {
    for_each = var.origin

    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config

        content {
          http_port              = try(custom_origin_config.value.http_port, 80)
          https_port             = try(custom_origin_config.value.https_port, 443)
          origin_protocol_policy = try(custom_origin_config.value.origin_protocol_policy, "https-only")
          origin_ssl_protocols   = try(custom_origin_config.value.origin_ssl_protocols, ["TLSv1.2"])
        }
      }

      dynamic "custom_header" {
        for_each = origin.value.custom_header

        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }

  dynamic "default_cache_behavior" {
    for_each = [var.default_cache_behavior]
    iterator = iter

    content {
      target_origin_id = iter.value.target_origin_id
      # Use the cache policy from the variable or fallback to caching disabled
      cache_policy_id = try(iter.value.cache_policy_id, data.aws_cloudfront_cache_policy.caching_disabled.id)
      allowed_methods = try(iter.value.allowed_methods, ["GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT", "DELETE"])
      cached_methods  = try(iter.value.cached_methods, ["GET", "HEAD"])

      origin_request_policy_id = try(iter.value.origin_request_policy_id, data.aws_cloudfront_origin_request_policy.all_viewer.id)

      viewer_protocol_policy = try(iter.value.viewer_protocol_policy, "redirect-to-https")
      compress               = try(iter.value.compress, true)
    }

  }

  # Static assets cache behavior
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behavior
    iterator = iter

    content {
      path_pattern     = iter.value.path_pattern
      target_origin_id = iter.value.target_origin_id
      # Use the cache policy from the variable or fallback to caching optimized
      cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

      allowed_methods = try(iter.value.allowed_methods, ["GET", "HEAD", "OPTIONS"])
      cached_methods  = try(iter.value.cached_methods, ["GET", "HEAD"])

      viewer_protocol_policy = try(iter.value.viewer_protocol_policy, "redirect-to-https")
      compress               = try(iter.value.compress, true)
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.viewer_certificate.acm_certificate_arn
    ssl_support_method       = var.viewer_certificate.ssl_support_method
    minimum_protocol_version = var.viewer_certificate.minimum_protocol_version
    certificate_source       = var.viewer_certificate.certificate_source
    iam_certificate_id       = var.viewer_certificate.iam_certificate_id
  }

  # Geo restrictions
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


# Route53 record for CloudFront
resource "aws_route53_record" "cloudfront" {
  count = var.create_route53_record ? 1 : 0

  zone_id = var.route53_hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
