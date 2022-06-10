locals {
  consume_custom_certificate_role = var.sidecar_custom_certificate_role_arn != ""
  produce_custom_certificate_role  = var.sidecar_custom_certificate_account_id != ""
}

# Gets the ARN from a resource that is deployed by this module in order to
# get the proper partition, region and account number for the aws account
# where the resources are actually deployed. This prevents issues with
# deployment pipelines that runs on AWS and deploys to different accounts.
data "aws_arn" "cw_lg" {
  arn = aws_cloudwatch_log_group.cyral-sidecar-lg.arn
}

##################
# Sidecar profile
##################

data "aws_iam_policy_document" "sidecar_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "init_script_policy" {
  # Policy doc to allow sidecar to function inside an ASG
  statement {
    actions = [
      "ec2:DescribeTags",
      "autoscaling:CompleteLifecycleAction"
    ]
    resources = [
      "*"
    ]
  }

  # Cloudwatch permissions
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.cyral-sidecar-lg.arn}:*"
    ]
  }

  # Secrets Manager permissions
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = compact([
      "arn:${data.aws_arn.cw_lg.partition}:secretsmanager:${data.aws_arn.cw_lg.region}:${data.aws_arn.cw_lg.account}:secret:/cyral/*",
      "arn:${data.aws_arn.cw_lg.partition}:secretsmanager:${data.aws_arn.cw_lg.region}:${data.aws_arn.cw_lg.account}:secret:${var.secrets_location}*"
    ])
  }

  source_policy_documents = [
    data.aws_iam_policy_document.kms.json
  ]
}

data "aws_iam_policy_document" "kms" {
  # KMS permissions
  dynamic "statement" {
    for_each = var.secrets_kms_key_id != "" ? [1] : []
    content {
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ]
      resources = [
        "${var.secrets_kms_key_id}"
      ]
    }
  }
}

data "aws_iam_policy_document" "assume_sidecar_custom_certificate_role" {
  count = local.consume_custom_certificate_role ? 1 : 0
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [var.sidecar_custom_certificate_role_arn]
  }
}

resource "aws_iam_instance_profile" "sidecar_profile" {
  name = "${var.name_prefix}-sidecar_profile"
  role = aws_iam_role.sidecar_role.name
}

resource "aws_iam_role" "sidecar_role" {
  name               = "${var.name_prefix}-sidecar_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.sidecar_trust_policy.json
}

resource "aws_iam_policy" "init_script_policy" {
  name        = "${var.name_prefix}-init_script_policy"
  path        = "/"
  description = "Allow EC2 to update ASG when init complete"
  policy      = data.aws_iam_policy_document.init_script_policy.json
}

resource "aws_iam_role_policy_attachment" "init_script_policy" {
  role       = aws_iam_role.sidecar_role.name
  policy_arn = aws_iam_policy.init_script_policy.arn
}

resource "aws_iam_policy" "assume_sidecar_custom_certificate_role" {
  count       = local.consume_custom_certificate_role ? 1 : 0
  name        = "${var.name_prefix}-assume_sidecar_custom_certificate_role"
  description = "Allow sidecar to assume sidecar custom certificate role. This is usually needed for cross-account cases."
  policy      = data.aws_iam_policy_document.assume_sidecar_custom_certificate_role[0]
}

resource "aws_iam_role_policy_attachment" "assume_sidecar_custom_certificate_role" {
  count      = local.consume_custom_certificate_role ? 1 : 0
  role       = aws_iam_role.sidecar_role.name
  policy_arn = aws_iam_policy.assume_sidecar_custom_certificate_role[0].arn
}

resource "aws_iam_role_policy_attachment" "user_policies" {
  for_each   = toset(var.iam_policies)
  role       = aws_iam_role.sidecar_role.name
  policy_arn = each.value
}

##############################
# Sidecar created certificate
##############################

data "aws_iam_policy_document" "sidecar_created_certificate_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sidecar_created_certificate_lambda_execution" {
  # Cloudwatch permissions
  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:${data.aws_arn.cw_lg.partition}:logs:${data.aws_arn.cw_lg.region}:${data.aws_arn.cw_lg.account}:*"
    ]
  }
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  # Secrets Manager permissions
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:UpdateSecret"
    ]
    resources = [
      "arn:${data.aws_arn.cw_lg.partition}:secretsmanager:${data.aws_arn.cw_lg.region}:${data.aws_arn.cw_lg.account}:secret:/cyral/sidecars/${var.sidecar_id}/self-signed-certificate*"
    ]
  }

  source_policy_documents = [
    data.aws_iam_policy_document.kms.json
  ]
}

resource "aws_iam_role" "sidecar_created_certificate_lambda_execution" {
  name               = "${var.name_prefix}-sidecar_created_certificate_lambda_execution"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.sidecar_created_certificate_lambda_assume_role.json
}

resource "aws_iam_policy" "sidecar_created_certificate_lambda_execution" {
  name   = "${var.name_prefix}-sidecar_created_certificate_lambda_execution"
  path   = "/"
  policy = data.aws_iam_policy_document.sidecar_created_certificate_lambda_execution.json
}

resource "aws_iam_role_policy_attachment" "sidecar_created_certificate_lambda_execution" {
  role       = aws_iam_role.sidecar_created_certificate_lambda_execution.name
  policy_arn = aws_iam_policy.sidecar_created_certificate_lambda_execution.arn
}

#############################
# Sidecar custom certificate
#############################

data "aws_iam_policy_document" "sidecar_custom_certificate_assume_role" {
  count = local.produce_custom_certificate_role ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.sidecar_custom_certificate_account_id]
    }
  }
}

data "aws_iam_policy_document" "sidecar_custom_certificate_secrets_manager" {
  count = local.produce_custom_certificate_role ? 1 : 0
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:UpdateSecret"
    ]
    resources = [aws_secretsmanager_secret.sidecar_custom_certificate[0].id]
  }
}

resource "aws_iam_role" "sidecar_custom_certificate" {
  count              = local.produce_custom_certificate_role ? 1 : 0
  name               = "${var.name_prefix}-sidecar_custom_certificate_lambda_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.sidecar_custom_certificate_assume_role[0].json
}

resource "aws_iam_policy" "sidecar_custom_certificate_secrets_manager" {
  count  = local.produce_custom_certificate_role ? 1 : 0
  name   = "${var.name_prefix}-sidecar_custom_certificate_secrets_manager"
  path   = "/"
  policy = data.aws_iam_policy_document.sidecar_custom_certificate_secrets_manager[0].json
}

resource "aws_iam_role_policy_attachment" "sidecar_custom_certificate" {
  count      = local.produce_custom_certificate_role ? 1 : 0
  role       = aws_iam_role.sidecar_custom_certificate[0].name
  policy_arn = aws_iam_policy.sidecar_custom_certificate_secrets_manager[0].arn
}
