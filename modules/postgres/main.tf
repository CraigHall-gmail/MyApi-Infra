# checkov:skip=CKV_AZURE_130: Private endpoint requires VNet, delegated subnet, and private DNS zone
# which are not yet provisioned. Remediation is the same planned hardening task as CKV_AZURE_189.
# Public access is restricted to Azure-hosted services only via the 0.0.0.0/0.0.0.0 firewall sentinel.
resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  administrator_login    = var.admin_username
  administrator_password = var.admin_password

  version  = "16"
  sku_name = var.sku_name

  storage_mb                   = var.storage_mb
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  tags = var.tags

  lifecycle {
    # azurerm ~>3.x always sends zone in PATCH bodies; ignore it to prevent
    # "zone can only be changed when exchanged with standby_availability_zone" errors.
    ignore_changes = [zone]
  }
}

# checkov:skip=CKV_AZURE_131: The 0.0.0.0/0.0.0.0 sentinel is Azure's mechanism for allowing
# Azure-hosted services (Container Apps) to connect without opening to the public internet.
# This rule is removed as part of the same VNet/private-endpoint hardening task as CKV_AZURE_130.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}
