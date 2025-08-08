variable "service_name" {
  type = string
}

variable "oac_principal_arn" {
  description = "The Principal ARN for the CloudFront Origin Access Control (OAC). Use this in S3 bucket policies."
  type        = string
}
