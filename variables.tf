variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "wait_for_deployment" {
  description = "Wait for deployment to finish"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The domain name for the CloudFront distribution"
  type        = string
}

variable "price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_100" # NA + EU, cheapest
}

variable "is_ipv6_enabled" {
  description = "Whether the IPv6 is enabled for the distribution."
  type        = bool
  default     = null
}

variable "origin" {
  description = "The origin configuration for the CloudFront distribution"
  type = list(object({
    domain_name = string
    origin_id   = string
    custom_origin_config = optional(object({
      http_port              = optional(number)
      https_port             = optional(number)
      origin_protocol_policy = optional(string)
      origin_ssl_protocols   = optional(list(string))
    }))
    custom_header = optional(object({
      name  = string
      value = string
    }))
  }))
  default = null
}

variable "default_cache_behavior" {
  description = "The default cache behavior for the CloudFront distribution"
  type = object({
    target_origin_id         = string
    cache_policy_id          = optional(string)
    allowed_methods          = optional(list(string))
    cached_methods           = optional(list(string))
    origin_request_policy_id = optional(string)
    viewer_protocol_policy   = optional(string)
    compress                 = optional(bool)
  })
  default = null
}

variable "ordered_cache_behavior" {
  description = "The ordered cache behavior for the CloudFront distribution"
  type = list(object({
    path_pattern             = string
    target_origin_id         = string
    cache_policy_id          = optional(string)
    allowed_methods          = optional(list(string))
    cached_methods           = optional(list(string))
    origin_request_policy_id = optional(string)
    viewer_protocol_policy   = optional(string)
    compress                 = optional(bool)
  }))
  default = null
}

variable "viewer_certificate" {
  description = "The viewer certificate configuration for the CloudFront distribution"
  type = object({
    cloudfront_default_certificate = optional(bool)
    acm_certificate_arn            = optional(string)
    ssl_support_method             = optional(string)
    minimum_protocol_version       = optional(string)
    iam_certificate_id             = optional(string)
  })
  default = {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

variable "geo_restriction" {
  description = "The geo restriction configuration for the CloudFront distribution"
  type = object({
    restriction_type = string
    locations        = optional(list(string))
  })
  default = {
    restriction_type = "none"
  }
}

variable "create_route53_record" {
  description = "Whether to create a Route53 record for the CloudFront distribution"
  type        = bool
  default     = false
}

variable "route53_hosted_zone_id" {
  description = "The Route53 hosted zone ID"
  type        = string

  default = null
}
