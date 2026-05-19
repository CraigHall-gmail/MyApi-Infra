data "azurerm_client_config" "current" {}

# checkov:skip=CKV_AZURE_189: Public network access is required for GitHub Actions hosted runners to write
# secrets during terraform apply. Remediation requires a private endpoint and VNet-integrated runner,
# which is tracked as a planned hardening task. Access is restricted to RBAC identities only
# (enable_rbac_authorization = true) so no anonymous or key-based access is permitted.
# checkov:skip=CKV_AZURE_183: Network ACL default-deny requires the same private endpoint work as CKV_AZURE_189.
# checkov:skip=CKV2_AZURE_5: Private endpoint requires the same VNet/subnet infrastructure as CKV_AZURE_189.
resource "azurerm_key_vault" "this" {
  name                       = var.key_vault_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  tags                       = var.tags
}

# Terraform runner (GitHub Actions OIDC identity) — write secrets during provisioning
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "this" {
  name         = var.secret_name
  value        = var.secret_value
  content_type = "text/plain"
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}
