terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  name_prefix = "rtv-take-home"
  common_tags = {
    Project   = "rtv-cicd-attack-chain"
    Purpose   = "take-home-reproduction"
    ManagedBy = "terraform"
  }

  pivot_secrets = {
    code_hosting = {
      suffix      = "code-hosting-admin-token"
      description = "Obviously fake code-hosting credential for the bounded take-home lab."
      value       = { kind = "FAKE_DEMO_VALUE", value = "NOT-A-REAL-CODE-HOSTING-TOKEN" }
    }
    ci_platform = {
      suffix      = "ci-platform-admin-key"
      description = "Obviously fake CI-platform credential for the bounded take-home lab."
      value       = { kind = "FAKE_DEMO_VALUE", value = "NOT-A-REAL-CI-PLATFORM-KEY" }
    }
    data_warehouse = {
      suffix      = "data-warehouse-creds"
      description = "Obviously fake data-warehouse credential for the bounded take-home lab."
      value       = { host = "example.invalid", username = "fake_demo_user", password = "NOT-A-REAL-PASSWORD" }
    }
    saas_api = {
      suffix      = "saas-api-key"
      description = "Obviously fake SaaS credential for the bounded take-home lab."
      value       = { kind = "FAKE_DEMO_VALUE", value = "NOT-A-REAL-SAAS-KEY" }
    }
  }
}

resource "terraform_data" "dedicated_account_guardrail" {
  input = var.dedicated_account_acknowledgement

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
      error_message = "Active AWS credentials do not match aws_account_id."
    }
    precondition {
      condition     = var.dedicated_account_acknowledgement == "I understand this creates a disposable lab in a dedicated empty AWS account"
      error_message = "Set the exact dedicated-account acknowledgement shown in terraform.tfvars.example."
    }
  }
}
