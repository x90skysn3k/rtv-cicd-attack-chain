variable "aws_region" {
  description = "AWS region for speaker demo resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Name prefix for speaker demo resources"
  type        = string
  default     = "rtv-speaker-demo"
}
