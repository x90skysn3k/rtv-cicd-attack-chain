resource "aws_cloudwatch_log_group" "persistence" {
  name              = "/aws/lambda/${local.name_prefix}-persistence"
  retention_in_days = 3
  tags              = local.common_tags

  depends_on = [terraform_data.dedicated_account_guardrail]
}

resource "aws_iam_role" "lambda_execution" {
  name        = "${local.name_prefix}-lambda-execution"
  description = "Least-privilege execution role for the fixed take-home proof Lambda."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags       = local.common_tags
  depends_on = [terraform_data.dedicated_account_guardrail]
}

resource "aws_iam_role_policy" "lambda_logs_only" {
  name = "write-fixed-log-group-only"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.persistence.arn}:*"
    }]
  })
}

resource "aws_secretsmanager_secret" "pivot" {
  for_each = local.pivot_secrets

  name                    = "${local.name_prefix}/pivot/${each.value.suffix}"
  description             = each.value.description
  recovery_window_in_days = 0
  tags                    = merge(local.common_tags, { Scope = "fake-pivot-only" })

  depends_on = [terraform_data.dedicated_account_guardrail]
}

resource "aws_secretsmanager_secret_version" "pivot" {
  for_each = local.pivot_secrets

  secret_id     = aws_secretsmanager_secret.pivot[each.key].id
  secret_string = jsonencode(each.value.value)
}

resource "aws_iam_role" "pivot_reader" {
  name                 = "${local.name_prefix}-pivot-reader"
  description          = "Target of the single constrained take-home IAM edge."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnEquals = {
          "aws:PrincipalArn" = var.chain_source_principal_arn
        }
      }
    }]
  })

  tags       = local.common_tags
  depends_on = [terraform_data.dedicated_account_guardrail]
}

resource "aws_iam_role_policy" "pivot_reader" {
  name = "get-fake-pivot-secrets-only"
  role = aws_iam_role.pivot_reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [for secret in aws_secretsmanager_secret.pivot : secret.arn]
    }]
  })
}
