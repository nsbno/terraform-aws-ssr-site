data "aws_caller_identity" "this" {}

resource "aws_s3_bucket" "this" {
  bucket = "${data.aws_caller_identity.this.account_id}-${var.service_name}-static-files"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  ssm_parameters = {
    static_files_bucket_name = aws_s3_bucket.this.id
  }
}

resource "aws_ssm_parameter" "ssm_parameters" {
  for_each = local.ssm_parameters

  name  = "/__deployment__/applications/${var.service_name}/${each.key}"
  type  = "String"
  value = each.value
}
