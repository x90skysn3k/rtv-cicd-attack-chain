variable "aws_region" {
  description = "AWS region for speaker demo resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Expected dedicated demo AWS account ID. Terraform aborts if the active credentials point anywhere else."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for speaker demo resources"
  type        = string
  default     = "rtv-speaker-demo"
}
