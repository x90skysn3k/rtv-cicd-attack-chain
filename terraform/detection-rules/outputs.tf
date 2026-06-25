output "sns_topic_arn" {
  description = "SNS topic receiving EventBridge detection hits"
  value       = aws_sns_topic.alerts.arn
}

output "eventbridge_rule_names" {
  description = "Created EventBridge detection rules"
  value       = { for key, rule in aws_cloudwatch_event_rule.detections : key => rule.name }
}

output "cloudtrail_name" {
  description = "CloudTrail trail feeding management events to EventBridge"
  value       = aws_cloudtrail.management_events.name
}

output "cloudtrail_bucket" {
  description = "S3 bucket receiving CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving raw EventBridge detection events"
  value       = aws_cloudwatch_log_group.detections.name
}

output "next_steps" {
  value = <<-EOT

    Detection rule pack is deployed.

    If alert_email was set, confirm the SNS subscription email before rehearsal.
    Raw EventBridge matches are also written to ${aws_cloudwatch_log_group.detections.name}.
    Then run the attendee flow and speaker scripts. Each stage should publish
    at least one alert to ${aws_sns_topic.alerts.arn}.
  EOT
}
