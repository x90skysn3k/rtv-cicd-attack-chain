variable "aws_region" {
  description = "AWS region for the dedicated take-home account."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Expected dedicated empty AWS account ID; provider operations are restricted to it."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "chain_source_principal_arn" {
  description = "IAM user or role ARN allowed to traverse the single take-home AssumeRole edge."
  type        = string

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:(user|role)/.+$", var.chain_source_principal_arn))
    error_message = "chain_source_principal_arn must be an IAM user or role ARN."
  }
}

variable "dedicated_account_acknowledgement" {
  description = "Explicit acknowledgement required before creating disposable take-home resources."
  type        = string
}
