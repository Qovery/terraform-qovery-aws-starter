locals {
  database_environments = var.database.enabled ? (
    var.database.environments == null ? toset(keys(var.environments)) : setintersection(var.database.environments, toset(keys(var.environments)))
  ) : toset([])

  application_environments = var.application == null ? toset([]) : toset(keys(var.environments))
}

# IAM role that Qovery assumes in your AWS account to create and run the cluster.
resource "qovery_aws_credentials" "this" {
  organization_id = var.organization_id
  name            = var.name
  role_arn        = var.aws_role_arn
}

# EKS cluster. Karpenter provisions the nodes.
resource "qovery_cluster" "this" {
  organization_id = var.organization_id
  credentials_id  = qovery_aws_credentials.this.id
  name            = var.name
  cloud_provider  = "AWS"
  region          = var.aws_region

  features = {
    karpenter = {
      disk_size_in_gib             = var.cluster.disk_size_in_gib
      default_service_architecture = var.cluster.architecture
      qovery_node_pools = {
        requirements = [
          {
            key      = "InstanceFamily"
            operator = "In"
            values   = var.cluster.instance_families
          },
          {
            key      = "InstanceSize"
            operator = "In"
            values   = var.cluster.instance_sizes
          },
          {
            key      = "Arch"
            operator = "In"
            values   = [var.cluster.architecture]
          }
        ]

        # Spot applies to the default node pool, which runs the application workloads.
        # The stable node pool stays on on-demand instances.
        default_override = {
          spot_enabled = var.cluster.spot_enabled
        }
      }
    }
  }
}

resource "qovery_project" "this" {
  organization_id = var.organization_id
  name            = var.name
}

resource "qovery_environment" "this" {
  for_each = var.environments

  project_id = qovery_project.this.id
  cluster_id = qovery_cluster.this.id
  name       = each.key
  mode       = each.value
}

resource "qovery_database" "postgres" {
  for_each = local.database_environments

  environment_id = qovery_environment.this[each.key].id
  name           = var.database.name
  type           = "POSTGRESQL"
  version        = var.database.version
  mode           = var.database.mode
  accessibility  = var.database.accessibility
  storage        = var.database.storage

  # CPU and memory apply to a CONTAINER database. A MANAGED database uses instance_type.
  cpu           = var.database.mode == "CONTAINER" ? var.database.cpu : null
  memory        = var.database.mode == "CONTAINER" ? var.database.memory : null
  instance_type = var.database.mode == "MANAGED" ? var.database.instance_type : null
}

resource "qovery_application" "this" {
  for_each = local.application_environments

  environment_id = qovery_environment.this[each.key].id
  name           = var.application.name

  git_repository = {
    url          = var.application.git_url
    branch       = lookup(var.application.branches, each.key, var.application.default_branch)
    root_path    = var.application.root_path
    git_token_id = var.application.git_token_id
  }
  build_mode      = "DOCKER"
  dockerfile_path = var.application.dockerfile_path
  auto_deploy     = var.application.auto_deploy

  cpu                   = var.application.cpu
  memory                = var.application.memory
  min_running_instances = var.application.min_running_instances
  max_running_instances = var.application.max_running_instances

  ports = [
    {
      internal_port       = var.application.port
      external_port       = var.application.publicly_accessible ? 443 : null
      protocol            = "HTTP"
      publicly_accessible = var.application.publicly_accessible
    }
  ]

  healthchecks = {
    readiness_probe = {
      type = {
        tcp = {
          port = var.application.port
        }
      }
      initial_delay_seconds = 30
      period_seconds        = 10
      timeout_seconds       = 5
      success_threshold     = 1
      failure_threshold     = 3
    }
  }

  environment_variables = length(var.application.environment_variables) == 0 ? null : [
    for key, value in var.application.environment_variables : {
      key   = key
      value = value
    }
  ]

  # The connection string comes from the database's built-in DATABASE_URL_INTERNAL secret.
  # Qovery resolves the alias at deploy time, so the password never enters the Terraform state.
  secret_aliases = contains(local.database_environments, each.key) ? [
    {
      key   = var.application.database_url_variable
      value = "QOVERY_POSTGRESQL_Z${upper(split("-", qovery_database.postgres[each.key].id)[0])}_DATABASE_URL_INTERNAL"
    }
  ] : null
}

resource "qovery_deployment" "this" {
  for_each = var.deploy ? var.environments : {}

  environment_id = qovery_environment.this[each.key].id
  desired_state  = "RUNNING"

  depends_on = [
    qovery_database.postgres,
    qovery_application.this,
  ]
}
