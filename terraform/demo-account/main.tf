terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

data "aws_caller_identity" "current" {}

# GitHub Actions OIDC provider (once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Name    = "github-actions-oidc"
    Purpose = "rtv-demo"
  }
}

# Secrets Manager secret that holds the GitHub admin PAT.
# Populate the value out-of-band with a throwaway lab token after Terraform runs.
resource "aws_secretsmanager_secret" "github_pat" {
  name                    = var.secret_name
  description             = "GitHub admin PAT for RTV demo. Rotated every session."
  recovery_window_in_days = 0 # allow immediate re-create between sessions

  tags = {
    Purpose = "rtv-demo"
  }
}


# IAM role trusted for OIDC from the demo repo on pull_request events.
resource "aws_iam_role" "github_actions_demo" {
  name        = var.role_name
  description = "Scoped to GetSecretValue on demo PAT only. Student-facing."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Accept PR-triggered runs from the demo repo. The second pattern covers GitHub immutable OIDC subjects.
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:pull_request",
            "repo:${var.github_org}@*/${var.github_repo}@*:pull_request"
          ]
        }
      }
    }]
  })

  max_session_duration = 3600

  tags = {
    Purpose = "rtv-demo"
  }
}

# Tightest possible permissions policy: one action, one resource.
resource "aws_iam_role_policy" "github_actions_demo" {
  name = "get-demo-secret-only"
  role = aws_iam_role.github_actions_demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.github_pat.arn
    }]
  })
}
