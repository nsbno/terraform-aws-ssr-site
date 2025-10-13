locals {
  service_name    = "infrademo-demo-app"
  domain_name     = "petstore.infrademo.vydev.io"
  alb_domain_name = "lb.infrademo.vydev.io"
}


module "metadata" {
  source = "github.com/nsbno/terraform-aws-account-metadata?ref=x.y.z"
}

module "preview_url_mapper" {
  count  = var.environment == "test" ? 1 : 0
  source = "github.com/nsbno/terraform-aws-preview-url?ref=x.y.z"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  service_name = local.service_name
}

module "ssr" {
  source = "../../terraform-aws-ssr-site"

  providers = {
    aws.certificate_provider = aws.us_east_1
  }

  # Use preview environments only in test environment
  enable_wildcard_domain        = var.environment == "test" ? true : false
  preview_url_mapper_lambda_arn = var.environment == "test" ? module.preview_url_mapper[0].lambda_function_qualifier_arn : ""

  service_name    = local.service_name
  domain_name     = local.domain_name
  alb_domain_name = local.alb_domain_name

  route53_hosted_zone_id = module.metadata.dns.hosted_zone_id

  # Default is to create a new bucket, if you already have a bucket, use this instead
  # external_s3_bucket_id = aws_s3_bucket.existing.id # Uncomment this line to use an existing bucket
}

