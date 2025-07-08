variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "wait_for_deployment" {
  description = "Wait for deployment to finish"
  type        = bool
  default     = true
}

variable "enable_wildcard_domain" {
  description = "Whether to enable wildcard domain for the CloudFront distribution. Used for preview environments."
  type        = bool
  default     = false
}

variable "preview_url_mapper_lambda_arn" {
  description = "The ARN of the Lambda function to map domain to preview URLs"
  type        = string

  default = ""
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
  default     = true
}

variable "default_cache_behavior" {
  description = "The default cache behavior for the CloudFront distribution"
  type = object({
    cache_policy_id          = optional(string)
    origin_request_policy_id = optional(string)
    allowed_methods          = optional(list(string))
    cached_methods           = optional(list(string))
    viewer_protocol_policy   = optional(string)
    compress                 = optional(bool)
  })
  default = null
}

variable "ordered_cache_behavior" {
  description = "The ordered cache behavior for the CloudFront distribution"
  type = list(object({
    cache_policy_id          = optional(string)
    allowed_methods          = optional(list(string))
    cached_methods           = optional(list(string))
    origin_request_policy_id = optional(string)
    viewer_protocol_policy   = optional(string)
    compress                 = optional(bool)
  }))
  default = null
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

variable "route53_hosted_zone_id" {
  description = "The Route53 hosted zone ID"
  type        = string
}

variable "alb_domain_name" {
  description = "The DNS name of the ALB"
  type        = string
}

variable "s3_cache_path_pattern" {
  description = "The path patterns for the S3 cache behavior"
  type        = list(string)
}

variable "s3_website_endpoint" {
  description = "The S3 website endpoint"
  type        = string
}

variable "minimum_protocol_version" {
  description = "The minimum protocol version for the CloudFront distribution"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "ssl_support_method" {
  description = "The SSL support method for the CloudFront distribution"
  type        = string
  default     = "sni-only"
}

variable "certificate_validation_timeout" {
  description = "How long to wait for the certificate to be issued"
  type        = string

  default = "45m"
}

variable "additional_domain_names" {
  description = "Accept additional domain names for the SSR site"
  type = list(string)
  default = []
}