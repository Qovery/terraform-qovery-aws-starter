# Qovery AWS starter module

Terraform and OpenTofu module that sets up a Kubernetes platform on your own AWS account, run by [Qovery](https://www.qovery.com).

One `module` block gives you:

- an EKS cluster in your AWS account, with Karpenter for the nodes
- a project with staging and production environments (or any set you choose)
- a PostgreSQL database in each environment (optional)
- your application, built from a git repository and deployed to each environment (optional)

You do not write an EKS module, Helm releases or Kubernetes provider glue. Qovery creates the cluster, deploys your services and upgrades both. Everything runs in your AWS account.

Registry address: `qovery/aws-starter/qovery` ([Terraform Registry](https://registry.terraform.io/modules/Qovery/aws-starter/qovery/latest)). Until the module is listed on the OpenTofu Registry, OpenTofu users can use the GitHub source instead:

```hcl
source = "github.com/Qovery/terraform-qovery-aws-starter?ref=v0.1.1"
```

## Usage

```hcl
terraform {
  required_providers {
    qovery = {
      source  = "qovery/qovery"
      version = "~> 1.0"
    }
  }
}

# Reads the API token from the QOVERY_API_TOKEN environment variable.
provider "qovery" {}

module "qovery" {
  source  = "qovery/aws-starter/qovery"
  version = "~> 0.1"

  organization_id = "your-qovery-organization-id"
  name            = "acme"
  aws_role_arn    = "arn:aws:iam::123456789012:role/qovery-role"
  aws_region      = "eu-west-3"

  application = {
    git_url = "https://github.com/your-org/your-app.git"
    port    = 8080
  }
}
```

With these inputs the module creates the cluster, the `staging` and `production` environments, a Postgres database in each, and the application built from the `main` branch. The application reads the database connection string from `DATABASE_URL`.

Run it with Terraform:

```sh
export QOVERY_API_TOKEN="your-api-token"
terraform init
terraform apply
```

Or with OpenTofu:

```sh
export QOVERY_API_TOKEN="your-api-token"
tofu init
tofu apply
```

### Examples

- [examples/minimal](examples/minimal): the cluster and two environments, nothing else.
- [examples/complete](examples/complete): the cluster, two environments, Postgres in each, and an application with a different branch per environment.

## Prerequisites

- A Qovery organization. Sign up at [console.qovery.com](https://console.qovery.com).
- A Qovery API token, exported as `QOVERY_API_TOKEN`. Create one in the Qovery Console under Settings > API Tokens.
- An IAM role in your AWS account that Qovery can assume. Follow the [AWS installation guide](https://www.qovery.com/docs/getting-started/installation/aws) to create it, then pass its ARN as `aws_role_arn`.
- Terraform 1.6 or later, or OpenTofu 1.6 or later.

Clusters that Qovery creates and manages need a paid plan. Every paid plan starts with a 14-day free trial. The Free plan works with a Kubernetes cluster you already run, which this module does not create.

## How the database connection works

When Qovery creates a database, it adds built-in variables to the environment, including a `DATABASE_URL_INTERNAL` secret. The module gives the application a secret alias that points to it:

```hcl
secret_aliases = [
  {
    key   = "DATABASE_URL"
    value = "QOVERY_POSTGRESQL_Z${upper(split("-", qovery_database.postgres["production"].id)[0])}_DATABASE_URL_INTERNAL"
  }
]
```

Qovery resolves the alias when it deploys the application. The password is never set in Terraform, so it does not end up in your state file. Change the variable name with `application.database_url_variable`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `organization_id` | ID of the Qovery organization. | `string` | n/a | yes |
| `name` | Base name of the cluster, the project and the AWS credentials. 3 to 32 lowercase letters, digits and hyphens. | `string` | n/a | yes |
| `aws_role_arn` | ARN of the IAM role Qovery assumes in your AWS account. | `string` | n/a | yes |
| `aws_region` | AWS region of the EKS cluster. | `string` | `"us-east-2"` | no |
| `cluster` | Karpenter settings: `disk_size_in_gib` (50), `architecture` (`AMD64`), `instance_families`, `instance_sizes`, `spot_enabled` (`true`, applies to the default node pool only). | `object` | `{}` | no |
| `environments` | Map of environment name to mode: `DEVELOPMENT`, `STAGING`, `PRODUCTION` or `PREVIEW`. | `map(string)` | `{ staging = "STAGING", production = "PRODUCTION" }` | no |
| `database` | PostgreSQL settings: `enabled` (`true`), `environments` (null for all), `name` (`postgres`), `version` (`16`), `mode` (`CONTAINER` or `MANAGED`), `accessibility` (`PRIVATE`), `cpu` (250), `memory` (512), `storage` (10), `instance_type` (required for `MANAGED`). | `object` | `{}` | no |
| `application` | Application built from git: `git_url` (required), `name` (`app`), `git_token_id`, `branches` (per environment), `default_branch` (`main`), `root_path` (`/`), `dockerfile_path` (`Dockerfile`), `port` (8080), `publicly_accessible` (`true`), `cpu` (500), `memory` (512), `min_running_instances` (1), `max_running_instances` (1), `auto_deploy` (`true`), `database_url_variable` (`DATABASE_URL`), `environment_variables` (`{}`). Null creates no application. | `object` | `null` | no |
| `deploy` | Whether to deploy each environment after Terraform creates or changes it. | `bool` | `true` | no |

The application gets a TCP readiness probe on `port`. A publicly accessible port is exposed on 443 over HTTPS. For a private repository, create a `qovery_git_token` and pass its ID as `git_token_id`.

## Outputs

| Name | Description |
|------|-------------|
| `aws_credentials_id` | ID of the Qovery AWS credentials. |
| `cluster_id` | ID of the Qovery cluster. |
| `project_id` | ID of the Qovery project. |
| `environment_ids` | IDs of the environments, by environment name. |
| `database_ids` | IDs of the PostgreSQL databases, by environment name. |
| `application_ids` | IDs of the applications, by environment name. |
| `application_external_hosts` | Public hosts of the applications, by environment name. |

## Going further

The module covers a common starting point. For anything else, use the Qovery provider resources directly next to it, with the module outputs as inputs: more services, jobs, Helm charts, managed databases from the service catalog, custom domains or preview environments.

- [Qovery Terraform provider overview](https://www.qovery.com/interfaces/terraform-provider)
- [Provider documentation on the Terraform Registry](https://registry.terraform.io/providers/qovery/qovery/latest/docs)

## License

[MPL-2.0](LICENSE)
