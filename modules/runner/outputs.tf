output "job_name" {
  value       = azurerm_container_app_job.runner.name
  description = "Name of the ACA Job self-hosted runner"
}

output "job_id" {
  value       = azurerm_container_app_job.runner.id
  description = "Resource ID of the ACA Job self-hosted runner"
}
