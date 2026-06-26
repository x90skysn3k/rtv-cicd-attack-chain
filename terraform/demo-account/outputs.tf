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

    1. Create a dedicated throwaway GitHub repository from the public demo files:
       - copy github/workflow.yml to .github/workflows/ci.yml
       - copy github/demo-repo/ into the repository root
       - set the workflow variables AWS_ROLE_ARN and SECRET_NAME from these outputs

    2. Store a throwaway lab token in Secrets Manager:
       aws secretsmanager put-secret-value \
         --secret-id ${aws_secretsmanager_secret.github_pat.name} \
         --secret-string "classic_pat_value_from_throwaway_user"

    3. Use a dedicated self-hosted lab runner and enable fork pull request
       workflows only for the disposable demo repository.

    4. Walk attendee-runbook.md from a separate test account before using the
       lab with attendees.
  EOT
}
