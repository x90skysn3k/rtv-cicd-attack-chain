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
  region = var.aws_region
}

data "aws_caller_identity" "current" {}


locals {
  common_tags = merge(var.tags, { Purpose = "rtv-demo-detection" })

  rules = {
    github_oidc_assume_role = {
      description = "GitHub OIDC role assumption through AssumeRoleWithWebIdentity"
      pattern = {
        source      = ["aws.sts"]
        detail-type = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["sts.amazonaws.com"]
          eventName   = ["AssumeRoleWithWebIdentity"]
        }
      }
    }

    build_session_secret_read = {
      description = "Secrets Manager read from a build or chained session"
      pattern = {
        source      = ["aws.secretsmanager"]
        detail-type = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["secretsmanager.amazonaws.com"]
          eventName   = ["GetSecretValue"]
        }
      }
    }

    build_session_lambda_write = {
      description = "Lambda write from a build style identity"
      pattern = {
        source      = ["aws.lambda"]
        detail-type = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["lambda.amazonaws.com"]
          eventName   = ["CreateFunction", "UpdateFunctionCode"]
        }
      }
    }

    build_session_schedule_write = {
      description = "EventBridge schedule write from a build style identity"
      pattern = {
        source      = ["aws.events"]
        detail-type = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["events.amazonaws.com"]
          eventName   = ["PutRule", "PutTargets"]
        }
      }
    }

    role_chain_abuse = {
      description = "STS AssumeRole call during the role chain portion of the demo"
      pattern = {
        source      = ["aws.sts"]
        detail-type = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["sts.amazonaws.com"]
          eventName   = ["AssumeRole"]
        }
      }
    }
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_policy" "events_publish" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.name_prefix}-*"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "detections" {
  for_each = local.rules

  name          = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "sns" {
  for_each = local.rules

  rule      = aws_cloudwatch_event_rule.detections[each.key].name
  target_id = "sns-alert"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      account    = "$.account"
      event_name = "$.detail.eventName"
      principal  = "$.detail.userIdentity.arn"
      region     = "$.region"
      source     = "$.detail.eventSource"
      time       = "$.time"
    }

    input_template = jsonencode({
      account    = "<account>"
      event_name = "<event_name>"
      principal  = "<principal>"
      region     = "<region>"
      rule       = each.key
      source     = "<source>"
      time       = "<time>"
    })
  }
}
