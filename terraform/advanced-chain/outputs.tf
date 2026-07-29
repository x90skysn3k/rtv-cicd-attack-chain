output "aws_account_id" {
  description = "Expected account value for EXPECTED_AWS_ACCOUNT_ID."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Region value for AWS_REGION."
  value       = var.aws_region
}

output "chain_source_principal_arn" {
  description = "Principal value for EXPECTED_SOURCE_PRINCIPAL_ARN."
  value       = var.chain_source_principal_arn
}

output "lambda_exec_role_arn" {
  description = "Value for LAMBDA_EXEC_ROLE_ARN."
  value       = aws_iam_role.lambda_execution.arn
}

output "chain_target_role_arn" {
  description = "Value for CHAIN_TARGET_ROLE_ARN."
  value       = aws_iam_role.pivot_reader.arn
}

output "lambda_log_group_name" {
  description = "Fixed persistence proof log group."
  value       = aws_cloudwatch_log_group.persistence.name
}

output "pivot_secret_names" {
  description = "Fixed fake secret names consumed by the pivot-read script."
  value       = { for key, secret in aws_secretsmanager_secret.pivot : key => secret.name }
}

output "detection_log_group_name" {
  description = "CloudWatch Logs destination for matching management events."
  value       = aws_cloudwatch_log_group.detections.name
}

output "detection_rule_names" {
  description = "EventBridge rules observing each bounded chain action."
  value       = { for key, rule in aws_cloudwatch_event_rule.detection : key => rule.name }
}

output "cloudtrail_name" {
  description = "Management-event trail feeding the take-home observation path."
  value       = aws_cloudtrail.management_events.name
}
