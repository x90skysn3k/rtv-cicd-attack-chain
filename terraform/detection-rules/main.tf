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

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-trail"
  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}-management-events"
          }
        }
      },
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}-management-events"
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "management_events" {
  name                          = "${var.name_prefix}-management-events"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail]
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
  state         = "ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS"

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
