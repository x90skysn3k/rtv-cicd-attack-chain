variable "aws_region" {
  description = "AWS region for demo resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Expected dedicated demo AWS account ID. Terraform aborts if the active credentials point anywhere else."
  type        = string
}

variable "github_org" {
  description = "GitHub org containing the demo repo (throwaway org)"
  type        = string
}

variable "github_repo" {
  description = "Demo repo name within the org"
  type        = string
  default     = "cicd-demo"
}

variable "role_name" {
  description = "IAM role name for the student-facing OIDC trust"
  type        = string
  default     = "rtv-demo-oidc-role"
}

variable "secret_name" {
  description = "Secrets Manager secret name holding the GitHub admin PAT"
  type        = string
  default     = "demo/github-pat"
}
