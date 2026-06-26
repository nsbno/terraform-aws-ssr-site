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

output "certificate_validation_dns_records" {
  value = [for record in aws_route53_record.cert_validation : record.fqdn]
  description = "Route53 records for the doing DNS certificate validation of variable `domain_name`"
}
