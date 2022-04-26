locals {
  sidecar_created_certificate_lambda_code_version = "v0.1.0"
  sidecar_created_certificate_sidecar_hosts = "${var.sidecar_dns_name}" != "" ? (
    "${var.sidecar_dns_name}"
    ) : (
    "poc.cyral.com"
  )
}

resource "aws_lambda_function" "sidecar_created_certificate" {
  function_name = "${var.name_prefix}-sidecar_created_certificate"
  role          = aws_iam_role.sidecar_created_certificate_lambda_execution.arn
  runtime       = "go1.x"
  handler       = "certmgr-lambda"
  timeout       = 180
  s3_bucket     = "cyral-public-assets-${data.aws_arn.cw_lg.region}"
  s3_key        = "sidecar-created-certificate/${local.sidecar_created_certificate_lambda_code_version}/sidecar-created-certificate-lambda-${local.sidecar_created_certificate_lambda_code_version}.zip"

  environment {
    variables = {
      SIDECAR_CREATED_CERTIFICATE_AWS_REGION    = data.aws_arn.cw_lg.region
      SIDECAR_CREATED_CERTIFICATE_SIDECAR_ID    = var.sidecar_id
      SIDECAR_CREATED_CERTIFICATE_SIDECAR_HOSTS = local.sidecar_created_certificate_sidecar_hosts
    }
  }
}

resource "aws_lambda_invocation" "sidecar_created_certificate" {
  function_name = aws_lambda_function.sidecar_created_certificate.function_name
  input         = jsonencode({})
}
