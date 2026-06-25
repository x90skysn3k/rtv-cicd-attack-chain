variable "aws_region" {
  description = "AWS region for detection resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Expected dedicated demo AWS account ID. Terraform aborts if the active credentials point anywhere else."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for detection resources"
  type        = string
  default     = "rtv-cicd-detect"
}

variable "alert_email" {
  description = "Optional email address for SNS alerts. Leave empty to create the topic without an email subscription."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to detection resources"
  type        = map(string)
  default = {
    Project = "defcon-34-rtv"
  }
}
