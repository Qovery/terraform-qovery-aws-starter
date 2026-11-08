# An EKS cluster run by Qovery, with staging and production environments,
# a PostgreSQL database in each, and an application built from git.

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
  name            = "acme"
  aws_role_arn    = var.aws_role_arn
  aws_region      = "eu-west-3"

  cluster = {
    spot_enabled = false
  }

  environments = {
    staging    = "STAGING"
    production = "PRODUCTION"
  }

  database = {
    version = "16"
    mode    = "CONTAINER"
    storage = 20
  }

  application = {
    name            = "api"
    git_url         = "https://github.com/your-org/your-app.git"
    dockerfile_path = "Dockerfile"
    port            = 8080

    # staging builds the develop branch; production builds main, the default.
    branches = {
      staging = "develop"
    }

    environment_variables = {
      LOG_LEVEL = "info"
    }
  }
}

output "cluster_id" {
  value = module.qovery.cluster_id
}

output "environment_ids" {
  value = module.qovery.environment_ids
}

output "database_ids" {
  value = module.qovery.database_ids
}

output "application_urls" {
  value = { for env, host in module.qovery.application_external_hosts : env => "https://${host}" }
}
