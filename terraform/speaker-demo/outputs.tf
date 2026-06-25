output "lambda_exec_role_arn" {
  description = "Pass to speaker-scripts/01-deploy-persistence.sh as LAMBDA_EXEC_ROLE_ARN"
  value       = aws_iam_role.lambda_persistence_exec.arn
}

output "elevated_chain_target_arn" {
  description = "Pass to speaker-scripts/02-abuse-iam-chain.sh as ELEVATED_ROLE_ARN"
  value       = aws_iam_role.elevated_chain_target.arn
}

output "lambda_log_group" {
  description = "CloudWatch Log Group for persistence Lambda output"
  value       = aws_cloudwatch_log_group.lambda_persistence.name
}

output "pivot_secret_arns" {
  description = "Pivot secret ARNs reachable during Part B"
  value = {
    code_hosting   = aws_secretsmanager_secret.pivot_code_hosting.arn
    ci_platform    = aws_secretsmanager_secret.pivot_ci_platform.arn
    data_warehouse = aws_secretsmanager_secret.pivot_data_warehouse.arn
    saas_api       = aws_secretsmanager_secret.pivot_saas_api.arn
  }
}

output "pivot_secret_names" {
  description = "Pivot secret names (pass to speaker-scripts/03-pivot-secrets.sh)"
  value = [
    aws_secretsmanager_secret.pivot_code_hosting.name,
    aws_secretsmanager_secret.pivot_ci_platform.name,
    aws_secretsmanager_secret.pivot_data_warehouse.name,
    aws_secretsmanager_secret.pivot_saas_api.name,
  ]
}

output "aws_region" {
  value = var.aws_region
}

output "name_prefix" {
  value = var.name_prefix
}

output "next_steps" {
  value = <<-EOT

    Speaker demo infrastructure is up. Run the scripts in order during the
    Part B projector segment:

      export LAMBDA_EXEC_ROLE_ARN=${aws_iam_role.lambda_persistence_exec.arn}
      export ELEVATED_ROLE_ARN=${aws_iam_role.elevated_chain_target.arn}
      export AWS_REGION=${var.aws_region}
      export NAME_PREFIX=${var.name_prefix}

      ./speaker-scripts/01-deploy-persistence.sh    # creates Lambda + EventBridge schedule
      ./speaker-scripts/02-abuse-iam-chain.sh       # assumes the elevated role
      source /tmp/.rtv-demo-chain-creds             # continue as the chained role
      ./speaker-scripts/03-pivot-secrets.sh         # reads the pivot secrets

      ./speaker-scripts/99-teardown.sh              # cleanup after the talk
  EOT
}
