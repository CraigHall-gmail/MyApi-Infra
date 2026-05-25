output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Resource ID of the Virtual Network"
}

output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "Name of the Virtual Network"
}

output "aca_subnet_id" {
  value       = azurerm_subnet.aca.id
  description = "Subnet ID for the ACA Environment (snet-aca)"
}

output "postgres_subnet_id" {
  value       = azurerm_subnet.postgres.id
  description = "Subnet ID for the PostgreSQL Flexible Server (snet-postgres)"
}

output "private_endpoints_subnet_id" {
  value       = azurerm_subnet.private_endpoints.id
  description = "Subnet ID for private endpoint NICs (snet-private-endpoints)"
}

output "runner_subnet_id" {
  value       = azurerm_subnet.runner.id
  description = "Subnet ID for the ACA Jobs self-hosted runner (snet-runner)"
}
