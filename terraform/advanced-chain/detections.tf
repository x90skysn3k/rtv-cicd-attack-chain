locals {
  detection_rules = {
    create_function = {
      source      = ["aws.lambda"]
      detail-type = ["AWS API Call via CloudTrail"]
      detail = {
        eventSource = ["lambda.amazonaws.com"]
        eventName   = ["CreateFunction20150331"]
      }
    }
    persistence_schedule = {
      source      = ["aws.events"]
      detail-type = ["AWS API Call via CloudTrail"]
      detail = {
        eventSource = ["events.amazonaws.com"]
        eventName   = ["PutRule", "PutTargets"]
      }
    }
    assume_role = {
      source      = ["aws.sts"]
      detail-type = ["AWS API Call via CloudTrail"]
      detail = {
        eventSource = ["sts.amazonaws.com"]
        eventName   = ["AssumeRole"]
      }
    }
    get_pivot_secret = {
      source      = ["aws.secretsmanager"]
      detail-type = ["AWS API Call via CloudTrail"]
      detail = {
        eventSource = ["secretsmanager.amazonaws.com"]
        eventName   = ["GetSecretValue"]
      }
    }
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-trail"
  force_destroy = true
  tags          = local.common_tags

  depends_on = [terraform_data.dedicated_account_guardrail]
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

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-disposable-lab-events"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
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
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-management-events"
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
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-management-events"
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.cloudtrail.arn, "${aws_s3_bucket.cloudtrail.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "management_events" {
  name                          = "${local.name_prefix}-management-events"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags       = local.common_tags
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

resource "aws_cloudwatch_log_group" "detections" {
  name              = "/aws/events/${local.name_prefix}-detections"
  retention_in_days = 7
  tags              = local.common_tags

  depends_on = [terraform_data.dedicated_account_guardrail]
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge" {
  policy_name = "${local.name_prefix}-eventbridge-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "delivery.logs.amazonaws.com"] }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.detections.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_event_rule" "detection" {
  for_each = local.detection_rules

  name          = "${local.name_prefix}-detect-${replace(each.key, "_", "-")}"
  description   = "Take-home management-event observation: ${replace(each.key, "_", " ")}"
  event_pattern = jsonencode(each.value)
  state         = "ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS"
  tags          = local.common_tags

  depends_on = [aws_cloudtrail.management_events]
}

resource "aws_cloudwatch_event_target" "detection_logs" {
  for_each = local.detection_rules

  rule      = aws_cloudwatch_event_rule.detection[each.key].name
  target_id = "cloudwatch-log"
  arn       = aws_cloudwatch_log_group.detections.arn

  depends_on = [aws_cloudwatch_log_resource_policy.eventbridge]
}
