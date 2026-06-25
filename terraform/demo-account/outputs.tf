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

    1. Populate the PAT (manual):
       export PAT_VALUE='<classic PAT minted by the throwaway demo user>'
       aws secretsmanager put-secret-value \
         --secret-id ${aws_secretsmanager_secret.github_pat.name} \
         --secret-string "$PAT_VALUE" \
         --region ${var.aws_region}

    2. Bootstrap the demo repo:
       export DEMO_ORG=${var.github_org}
       export DEMO_REPO=${var.github_repo}
       export AWS_REGION=${var.aws_region}
       export AWS_ROLE_ARN=${aws_iam_role.github_actions_demo.arn}
       ./github/setup-repo.sh

    3. Install and start runner pool:
       ./runner-pool/install-runners.sh
       ./runner-pool/start-runners.sh

    4. Toggle repo settings per plan.md.

    5. Walk the attendee runbook from a test account end-to-end.
  EOT
}
