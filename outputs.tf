output "aws_credentials_id" {
  description = "ID of the Qovery AWS credentials."
  value       = qovery_aws_credentials.this.id
}

output "cluster_id" {
  description = "ID of the Qovery cluster."
  value       = qovery_cluster.this.id
}

output "project_id" {
  description = "ID of the Qovery project."
  value       = qovery_project.this.id
}

output "environment_ids" {
  description = "IDs of the environments, by environment name."
  value       = { for name, environment in qovery_environment.this : name => environment.id }
}

output "database_ids" {
  description = "IDs of the PostgreSQL databases, by environment name."
  value       = { for name, database in qovery_database.postgres : name => database.id }
}

output "application_ids" {
  description = "IDs of the applications, by environment name."
  value       = { for name, application in qovery_application.this : name => application.id }
}

output "application_external_hosts" {
  description = "Public hosts of the applications, by environment name. Empty when the application port is not publicly accessible."
  value       = { for name, application in qovery_application.this : name => application.external_host }
}
