locals {
  service_name    = "infrademo-demo-app"
  domain_name     = "petstore.infrademo.vydev.io"
  alb_domain_name = "lb.infrademo.vydev.io"
}


module "metadata" {
  source = "github.com/nsbno/terraform-aws-account-metadata?ref=x.y.z"
}

module "s3_static_files" {
  source = "../../terraform-aws-ssr-site/modules/s3_static_files"

  service_name               = local.service_name
  cloudfront_distribution_id = module.ssr.cloudfront_distribution_id
}

module "ssr" {
  source = "../../terraform-aws-ssr-site"

  providers = {
    aws.certificate_provider = aws.us_east_1
  }

  service_name    = local.service_name
  domain_name     = local.domain_name
  alb_domain_name = local.alb_domain_name

  route53_hosted_zone_id = module.metadata.dns.hosted_zone_id
  s3_bucket_id           = module.s3_static_files.bucket_id
}
