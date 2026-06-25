###############################################################################
# Speaker demo IAM: the "elevated" side of the chain.
#
# Pre-created:
#   - Lambda execution role: what the persistence Lambda runs as
#   - Elevated chain target role: what a compromised build role could assume
#   - Log group for Lambda output (Lambda auto-creates too, but this lets us
#     pre-tag and pre-set retention)
#
# Created live by the speaker script (not Terraform):
#   - Lambda function
#   - EventBridge rule + target
###############################################################################

# The "pivot target" role representing broader cloud access.
# In a real environment this might be production-admin, a cross-account role,
# or a role with heavier data-access permissions.
resource "aws_iam_role" "elevated_chain_target" {
  name        = "${var.name_prefix}-elevated-chain-target"
  description = "Speaker demo: represents the cross-account / broader-privilege target reachable from a compromised build role."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        # Demo account trusts itself. In the real pattern this is a separate
        # account, cross-account trust, or an IAM role exposed via a
        # misconfigured trust policy.
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })

  max_session_duration = 3600

  tags = { Purpose = "rtv-demo-speaker" }
}

resource "aws_iam_role_policy" "elevated_chain_target" {
  name = "pivot-read"
  role = aws_iam_role.elevated_chain_target.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
}

# Lambda execution role for the persistence Lambda.
# The speaker passes this role to the Lambda when CreateFunction is called.
resource "aws_iam_role" "lambda_persistence_exec" {
  name        = "${var.name_prefix}-lambda-exec"
  description = "Execution role for the persistence Lambda demoed live."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Purpose = "rtv-demo-speaker" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_persistence_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_persistence" {
  name = "persistence-access"
  role = aws_iam_role.lambda_persistence_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:AssumeRole",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue",
        ]
        Resource = "*"
      },
    ]
  })
}

# Pre-created log group so speaker scripts know where to tail.
# Lambda will auto-create if this doesn't exist, but pre-creating lets us set
# retention and tag it.
resource "aws_cloudwatch_log_group" "lambda_persistence" {
  name              = "/aws/lambda/${var.name_prefix}-cred-relay"
  retention_in_days = 3

  tags = { Purpose = "rtv-demo-speaker" }
}
