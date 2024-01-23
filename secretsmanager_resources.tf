locals {
  sidecar_secrets = {
    clientId                    = var.client_id
    clientSecret                = var.client_secret
    containerRegistryKey        = var.container_registry_key
    sidecarPublicIdpCertificate = replace(var.sidecar_public_idp_certificate, "\n", "\\n")
    sidecarPrivateIdpKey        = replace(var.sidecar_private_idp_key, "\n", "\\n")
  }
  create_sidecar_custom_certificate_secret = var.sidecar_custom_certificate_account_id != ""
  sidecar_creds_secret_name                = var.secrets_location != "" ? var.secrets_location : "/cyral/sidecars/${var.sidecar_id}/secrets"
  sidecar_created_certificate_secret_name  = "/cyral/sidecars/${var.sidecar_id}/self-signed-certificate"
  sidecar_ca_certificate_secret_name       = "/cyral/sidecars/${var.sidecar_id}/ca-certificate"
}

# TODO: Remove `moved` in next major
moved {
  from = aws_secretsmanager_secret.cyral-sidecar-secret
  to   = aws_secretsmanager_secret.sidecar_secrets
}
resource "aws_secretsmanager_secret" "sidecar_secrets" {
  count                   = var.deploy_secrets ? 1 : 0
  name                    = local.sidecar_creds_secret_name
  recovery_window_in_days = 0
  kms_key_id              = var.secrets_kms_arn
}

# TODO: Remove `moved` in next major
moved {
  from = aws_secretsmanager_secret_version.cyral-sidecar-secret-version
  to   = aws_secretsmanager_secret_version.sidecar_secrets
}
resource "aws_secretsmanager_secret_version" "sidecar_secrets" {
  count         = var.deploy_secrets ? 1 : 0
  secret_id     = aws_secretsmanager_secret.sidecar_secrets[0].id
  secret_string = jsonencode(local.sidecar_secrets)
}

# TODO: Remove `moved` in next major
moved {
  from = aws_secretsmanager_secret.sidecar_created_certificate
  to   = aws_secretsmanager_secret.self_signed_tls_cert
}
resource "aws_secretsmanager_secret" "self_signed_tls_cert" {
  name                    = local.sidecar_created_certificate_secret_name
  description             = "Self-signed TLS certificate used by sidecar in case a custom certificate is not provided."
  recovery_window_in_days = 0
  kms_key_id              = var.secrets_kms_arn
}

# TODO: Remove `moved` in next major
moved {
  from = aws_secretsmanager_secret.sidecar_ca_certificate
  to   = aws_secretsmanager_secret.self_signed_ca
}
resource "aws_secretsmanager_secret" "self_signed_ca" {
  name                    = local.sidecar_ca_certificate_secret_name
  description             = "CA certificate used by sidecar in case a custom CA certificate is not provided."
  recovery_window_in_days = 0
  kms_key_id              = var.secrets_kms_arn
}

moved {
  from = aws_secretsmanager_secret.sidecar_custom_certificate
  to   = aws_secretsmanager_secret.custom_tls_certificate
}
resource "aws_secretsmanager_secret" "custom_tls_certificate" {
  count                   = local.create_sidecar_custom_certificate_secret ? 1 : 0
  name                    = "/cyral/sidecars/certificate/${local.name_prefix}"
  description             = "Custom certificate used by Cyral sidecar for TLS. This secret will be controlled by the Sidecar Custom Certificate module."
  recovery_window_in_days = 0
  kms_key_id              = var.secrets_kms_arn
}

resource "aws_lambda_function" "self_signed_certificate" {
  function_name    = "${local.name_prefix}-self_signed_certificate"
  description      = "Generates certificates for the sidecar when needed"
  role             = aws_iam_role.self_signed_certificate.arn
  runtime          = "python3.10"
  filename         = "${path.module}/files/self-signed-certificate-lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/files/self-signed-certificate-lambda.zip")
  handler          = "index.handler"
  layers = [
    "arn:aws:lambda:${local.aws_region}:155826672581:layer:pyopenssl:1"
  ]
  timeout = 120
}

resource "aws_lambda_invocation" "self_signed_tls_certificate" {
  function_name = aws_lambda_function.self_signed_certificate.function_name
  input = jsonencode({
    SecretId        = aws_secretsmanager_secret.self_signed_tls_cert.id
    Hostname        = local.sidecar_endpoint
    IsCACertificate = false
  })
}

resource "aws_lambda_invocation" "self_signed_ca_certificate" {
  function_name = aws_lambda_function.self_signed_certificate.function_name
  input = jsonencode({
    SecretId        = aws_secretsmanager_secret.self_signed_ca.id
    Hostname        = local.sidecar_endpoint
    IsCACertificate = true
  })
}
