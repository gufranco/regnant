# Policy attached to the Sovereign role granting read access to the
# SSM parameters this module manages.

data "aws_iam_role" "sovereign" {
  name = var.iam_role_names["sovereign"]
}

data "aws_iam_policy_document" "sovereign_ssm" {
  statement {
    sid    = "ReadSovereignParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DescribeParameters",
    ]
    resources = [
      aws_ssm_parameter.artifact_bucket.arn,
      aws_ssm_parameter.artifact_prefix.arn,
      aws_ssm_parameter.redis_url.arn,
      aws_ssm_parameter.log_level.arn,
      aws_ssm_parameter.matched_service.arn,
      aws_ssm_parameter.refresh_interval.arn,
      aws_ssm_parameter.leaf_secret_arns_json.arn,
      aws_ssm_parameter.ca_secret_arn.arn,
    ]
  }

  statement {
    sid    = "KmsForSecureStringParameter"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arns["secrets"]]
  }
}

resource "aws_iam_policy" "sovereign_ssm" {
  name        = "${var.name_prefix}-sovereign-ssm-read"
  description = "Read Sovereign configuration parameters."
  policy      = data.aws_iam_policy_document.sovereign_ssm.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "sovereign_ssm" {
  role       = data.aws_iam_role.sovereign.name
  policy_arn = aws_iam_policy.sovereign_ssm.arn
}
