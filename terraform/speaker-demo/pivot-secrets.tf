###############################################################################
# Pivot secrets: fake credentials representing what a real compromised org
# would have stored in Secrets Manager. The speaker reads these live during
# Part B to demonstrate the AWS -> everywhere pivot.
#
# All values are obviously fake. If you see real credentials here you've done
# something wrong.
###############################################################################

resource "aws_secretsmanager_secret" "pivot_code_hosting" {
  name                    = "demo/pivot/code-hosting-admin-token"
  description             = "Speaker demo: represents a GitHub/GitLab admin PAT stored for CI use."
  recovery_window_in_days = 0

  tags = { Purpose = "rtv-demo-speaker", Scope = "pivot" }
}

resource "aws_secretsmanager_secret_version" "pivot_code_hosting" {
  secret_id     = aws_secretsmanager_secret.pivot_code_hosting.id
  secret_string = "DEMO-FAKE-ghp_ZXhhbXBsZV9ub3RfcmVhbF9jb21waWxlZF90b2tlbg"
}

resource "aws_secretsmanager_secret" "pivot_ci_platform" {
  name                    = "demo/pivot/ci-platform-admin-key"
  description             = "Speaker demo: represents a CI platform admin API key."
  recovery_window_in_days = 0

  tags = { Purpose = "rtv-demo-speaker", Scope = "pivot" }
}

resource "aws_secretsmanager_secret_version" "pivot_ci_platform" {
  secret_id = aws_secretsmanager_secret.pivot_ci_platform.id
  secret_string = jsonencode({
    api_key = "DEMO-FAKE-ci-admin-key-not-real"
    org_id  = "demo-org-12345"
    scope   = "admin:all"
    usage   = "CI platform org admin API key"
  })
}

resource "aws_secretsmanager_secret" "pivot_data_warehouse" {
  name                    = "demo/pivot/data-warehouse-creds"
  description             = "Speaker demo: represents credentials for a data warehouse with customer data."
  recovery_window_in_days = 0

  tags = { Purpose = "rtv-demo-speaker", Scope = "pivot" }
}

resource "aws_secretsmanager_secret_version" "pivot_data_warehouse" {
  secret_id = aws_secretsmanager_secret.pivot_data_warehouse.id
  secret_string = jsonencode({
    host     = "warehouse.demo.internal"
    user     = "etl_admin"
    password = "DEMO-FAKE-password-not-real"
    database = "customer_events"
  })
}

resource "aws_secretsmanager_secret" "pivot_saas_api" {
  name                    = "demo/pivot/saas-api-key"
  description             = "Speaker demo: represents a SaaS vendor API key (observability, billing, etc)."
  recovery_window_in_days = 0

  tags = { Purpose = "rtv-demo-speaker", Scope = "pivot" }
}

resource "aws_secretsmanager_secret_version" "pivot_saas_api" {
  secret_id = aws_secretsmanager_secret.pivot_saas_api.id
  secret_string = jsonencode({
    vendor  = "demo-saas-vendor"
    api_key = "DEMO-FAKE-saas-key-not-real"
    scope   = "org:admin"
  })
}
