output "cloudfront_distribution_id" {
  description = "The identifier for the distribution."
  value       = try(aws_cloudfront_distribution.this.id, "")
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID that can be used to route an Alias Resource Record Set to."
  value       = try(aws_cloudfront_distribution.this.hosted_zone_id, "")
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name corresponding to the distribution."
  value       = try(aws_cloudfront_distribution.this.domain_name, "")
}

output "oac_principal_arn" {
  description = "The Principal ARN for the CloudFront Origin Access Control (OAC). Use this in S3 bucket policies."
  value       = aws_cloudfront_origin_access_control.this.arn
}