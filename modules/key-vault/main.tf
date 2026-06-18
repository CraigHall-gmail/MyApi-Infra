data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                          = var.key_vault_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
}

resource "azurerm_private_endpoint" "this" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-${var.key_vault_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dzg-${var.key_vault_name}"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# Terraform runner (GitHub Actions OIDC identity) — write secrets during provisioning
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "this" {
  name            = var.secret_name
  value           = var.secret_value
  content_type    = "text/plain"
  expiration_date = timeadd(plantimestamp(), var.secret_expiry_duration)
  key_vault_id    = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.kv_secrets_officer, azurerm_private_endpoint.this]
}
