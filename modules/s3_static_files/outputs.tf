output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.this.website_endpoint
}

output "oac_principal_arn" {
  description = "The Principal ARN for the CloudFront Origin Access Control (OAC). Use this in S3 bucket policies."
  value       = aws_cloudfront_origin_access_control.this.iam_arn
}