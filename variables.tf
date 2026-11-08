variable "organization_id" {
  description = "ID of the Qovery organization that owns the cluster and the project."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "organization_id must be a UUID, for example 01234567-89ab-cdef-0123-456789abcdef."
  }
}

variable "name" {
  description = "Base name of the resources. The cluster, the project and the AWS credentials are named after it."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3 to 32 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "aws_role_arn" {
  description = "ARN of the IAM role Qovery assumes in your AWS account. Create it with the CloudFormation stack from https://www.qovery.com/docs/getting-started/installation/aws."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.aws_role_arn))
    error_message = "aws_role_arn must be an IAM role ARN, for example arn:aws:iam::123456789012:role/qovery-role."
  }
}

variable "aws_region" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be an AWS region code, for example us-east-2 or eu-west-3."
  }
}

variable "cluster" {
  description = "Karpenter settings of the EKS cluster. The defaults allow a wide range of instance types, which makes node allocation fail less often."
  type = object({
    disk_size_in_gib  = optional(number, 50)
    architecture      = optional(string, "AMD64")
    instance_families = optional(list(string), ["c6i", "c7i", "m6i", "m7i", "r6i", "r7i", "t3", "t3a"])
    instance_sizes    = optional(list(string), ["medium", "large", "xlarge", "2xlarge", "4xlarge"])
    spot_enabled      = optional(bool, true)
  })
  default = {}

  validation {
    condition     = var.cluster.disk_size_in_gib >= 20
    error_message = "cluster.disk_size_in_gib must be at least 20."
  }

  validation {
    condition     = contains(["AMD64", "ARM64"], var.cluster.architecture)
    error_message = "cluster.architecture must be AMD64 or ARM64."
  }

  validation {
    condition     = length(var.cluster.instance_families) > 0 && length(var.cluster.instance_sizes) > 0
    error_message = "cluster.instance_families and cluster.instance_sizes must each list at least one value."
  }
}

variable "environments" {
  description = "Environments to create in the project, as a map of environment name to mode (DEVELOPMENT, STAGING, PRODUCTION or PREVIEW)."
  type        = map(string)
  default = {
    staging    = "STAGING"
    production = "PRODUCTION"
  }

  validation {
    condition     = length(var.environments) > 0
    error_message = "environments must declare at least one environment."
  }

  validation {
    condition     = alltrue([for mode in values(var.environments) : contains(["DEVELOPMENT", "STAGING", "PRODUCTION", "PREVIEW"], mode)])
    error_message = "Each environment mode must be DEVELOPMENT, STAGING, PRODUCTION or PREVIEW."
  }
}

variable "database" {
  description = "PostgreSQL database created in each environment. Set enabled to false to skip it, or list the environments that get one in environments (null means all of them). CONTAINER runs Postgres on the cluster; MANAGED uses Amazon RDS and needs instance_type."
  type = object({
    enabled       = optional(bool, true)
    environments  = optional(set(string))
    name          = optional(string, "postgres")
    version       = optional(string, "16")
    mode          = optional(string, "CONTAINER")
    accessibility = optional(string, "PRIVATE")
    cpu           = optional(number, 250)
    memory        = optional(number, 512)
    storage       = optional(number, 10)
    instance_type = optional(string)
  })
  default = {}

  validation {
    condition     = contains(["CONTAINER", "MANAGED"], var.database.mode)
    error_message = "database.mode must be CONTAINER or MANAGED."
  }

  validation {
    condition     = var.database.mode == "CONTAINER" || var.database.instance_type != null
    error_message = "database.instance_type is required when database.mode is MANAGED, for example db.t3.micro."
  }

  validation {
    condition     = contains(["PRIVATE", "PUBLIC"], var.database.accessibility)
    error_message = "database.accessibility must be PRIVATE or PUBLIC."
  }

  validation {
    condition     = var.database.cpu >= 250 && var.database.memory >= 100 && var.database.storage >= 10
    error_message = "database.cpu must be at least 250, database.memory at least 100 and database.storage at least 10."
  }
}

variable "application" {
  description = "Application built from a git repository and deployed in every environment. Leave it null to create no application. The branch defaults to main and can be set per environment in branches. When the environment has a database, the application reads its connection string from the variable named database_url_variable."
  type = object({
    name                  = optional(string, "app")
    git_url               = string
    git_token_id          = optional(string)
    branches              = optional(map(string), {})
    default_branch        = optional(string, "main")
    root_path             = optional(string, "/")
    dockerfile_path       = optional(string, "Dockerfile")
    port                  = optional(number, 8080)
    publicly_accessible   = optional(bool, true)
    cpu                   = optional(number, 500)
    memory                = optional(number, 512)
    min_running_instances = optional(number, 1)
    max_running_instances = optional(number, 1)
    auto_deploy           = optional(bool, true)
    database_url_variable = optional(string, "DATABASE_URL")
    environment_variables = optional(map(string), {})
  })
  default = null

  validation {
    condition     = try(can(regex("^https://", var.application.git_url)), var.application == null)
    error_message = "application.git_url must be an HTTPS URL, for example https://github.com/my-org/my-app.git."
  }

  validation {
    condition     = try(var.application.port >= 1 && var.application.port <= 65535, var.application == null)
    error_message = "application.port must be between 1 and 65535."
  }

  validation {
    condition     = try(var.application.min_running_instances <= var.application.max_running_instances, var.application == null)
    error_message = "application.min_running_instances must not exceed application.max_running_instances."
  }

  validation {
    condition     = try(can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.application.database_url_variable)), var.application == null)
    error_message = "application.database_url_variable must be a valid environment variable name, for example DATABASE_URL."
  }
}

variable "deploy" {
  description = "Whether to deploy each environment after Terraform creates or changes it. Set to false to create the resources without deploying them."
  type        = bool
  default     = true
}
