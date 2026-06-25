output "role_arn" {
  description = "Paste into repo variable AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions_demo.arn
}

output "secret_arn" {
  description = "Secrets Manager ARN for the GitHub PAT"
  value       = aws_secretsmanager_secret.github_pat.arn
}

output "secret_name" {
  description = "Secrets Manager secret name for `aws secretsmanager get-secret-value --secret-id`"
  value       = aws_secretsmanager_secret.github_pat.name
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "aws_region" {
  value = var.aws_region
}

output "next_steps" {
  value = <<-EOT

    1. Bootstrap the demo repo and seed the PAT:
       export DEMO_ORG=${var.github_org}
       export DEMO_REPO=${var.github_repo}
       export AWS_REGION=${var.aws_region}
       export AWS_ROLE_ARN=${aws_iam_role.github_actions_demo.arn}
       export SECRET_NAME=${aws_secretsmanager_secret.github_pat.name}
       export EXPECTED_AWS_ACCOUNT_ID=${var.aws_account_id}
       export EXPECTED_GITHUB_USER=throwaway-user
       export PAT_VALUE=classic_pat_value_from_throwaway_user
       ./github/setup-repo.sh

    2. Install and start runner pool:
       ./runner-pool/install-runners.sh
       ./runner-pool/start-runners.sh

    3. Toggle repo settings per plan.md.

    4. Walk the attendee runbook from a test account end-to-end.
  EOT
}
