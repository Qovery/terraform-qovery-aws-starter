# An EKS cluster run by Qovery, with a staging and a production environment.
# No database and no application.

terraform {
  required_version = ">= 1.6"

  required_providers {
    qovery = {
      source  = "qovery/qovery"
      version = "~> 1.0"
    }
  }
}

# Reads the API token from the QOVERY_API_TOKEN environment variable.
provider "qovery" {}

variable "organization_id" {
  description = "ID of the Qovery organization."
  type        = string
}

variable "aws_role_arn" {
  description = "ARN of the IAM role Qovery assumes in your AWS account."
  type        = string
}

module "qovery" {
  source = "../../"

  organization_id = var.organization_id
  name            = "starter"
  aws_role_arn    = var.aws_role_arn
  aws_region      = "us-east-2"

  database = {
    enabled = false
  }
}

output "cluster_id" {
  value = module.qovery.cluster_id
}

output "environment_ids" {
  value = module.qovery.environment_ids
}
