terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-myapi-tfstate"
    storage_account_name = "myapiterraformstate"
    container_name       = "tfstate"
    key                  = "development/api.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  # Credentials injected via ARM_* env vars in GitHub Actions (OIDC)
}

data "azurerm_client_config" "current" {}

# ── Private DNS Zones ───────────────────────────────────────────────────────────

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.pg_server_name}.private.postgres.database.azure.com"
  resource_group_name = module.environment.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "link-postgres-vnet-myapi-dev"
  resource_group_name   = module.environment.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = module.environment.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "link-kv-vnet-myapi-dev"
  resource_group_name   = module.environment.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ── Modules ────────────────────────────────────────────────────────────────────
module "vnet" {
  source = "../modules/vnet"

  vnet_name                     = "vnet-myapi-dev"
  resource_group_name           = module.environment.resource_group_name
  location                      = module.environment.location
  address_space                 = var.vnet_address_space
  aca_subnet_cidr               = "10.0.0.0/23"
  postgres_subnet_cidr          = "10.0.4.0/24"
  private_endpoints_subnet_cidr = "10.0.5.0/24"
  runner_subnet_cidr            = "10.0.6.0/27"
  tags                          = var.tags
}

module "environment" {
  source = "../modules/app-environment"

  resource_group           = var.resource_group
  location                 = var.location
  law_name                 = var.law_name_env
  aca_env_name             = var.aca_name_env
  infrastructure_subnet_id = module.vnet.aca_subnet_id
  tags                     = var.tags
}

module "runner" {
  source = "../modules/runner"

  job_name            = "job-runner-dev"
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  aca_env_id          = module.environment.aca_env_id
  github_owner        = var.github_owner
  github_repo         = var.github_repo
  runner_pat          = var.runner_pat
  environment         = "dev"
  runner_labels       = "self-hosted,azure,dev"
  tags                = var.tags
}

module "runner_app" {
  source = "../modules/runner"

  job_name            = "job-runner-app-dev"
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  aca_env_id          = module.environment.aca_env_id
  github_owner        = var.github_owner
  github_repo         = "MyApi"
  runner_pat          = var.runner_app_pat
  environment         = "dev"
  runner_labels       = "self-hosted,azure,dev"
  tags                = var.tags
}

module "api_app" {
  source = "../modules/container-app"

  app_name            = var.app_name
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  aca_env_id          = module.environment.aca_env_id
  acr_name            = var.acr_name
  acr_resource_group  = var.acr_resource_group
  tags                = var.tags

  cpu                    = var.cpu
  memory                 = var.memory
  min_replicas           = var.min_replicas
  max_replicas           = var.max_replicas
  aspnetcore_environment = var.aspnetcore_environment
}

module "postgres" {
  # checkov:skip=CKV_AZURE_136: B_Standard_B1ms Burstable SKU does not support geo-redundant backups
  source = "../modules/postgres"

  server_name                  = var.pg_server_name
  resource_group_name          = module.environment.resource_group_name
  location                     = module.environment.location
  admin_password               = var.pg_admin_password
  sku_name                     = var.pg_sku_name
  storage_mb                   = var.pg_storage_mb
  geo_redundant_backup_enabled = var.pg_geo_redundant_backup
  delegated_subnet_id          = module.vnet.postgres_subnet_id
  private_dns_zone_id          = azurerm_private_dns_zone.postgres.id
  tags                         = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

module "key_vault" {
  source = "../modules/key-vault"

  key_vault_name             = var.pg_key_vault_name
  resource_group_name        = module.environment.resource_group_name
  location                   = module.environment.location
  secret_value               = module.postgres.connection_string
  private_endpoint_subnet_id = module.vnet.private_endpoints_subnet_id
  private_dns_zone_id        = azurerm_private_dns_zone.key_vault.id
  tags                       = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.key_vault]
}

# Grant the ACA managed identity read access to the Key Vault so it can be
# used by the CD pipeline and migration workflow to fetch the connection string.
resource "azurerm_role_assignment" "kv_aca_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.api_app.identity_principal_id
}

# GitHub Actions service principal — recreated automatically on every provision
resource "azurerm_role_assignment" "gh_contributor" {
  scope                = module.environment.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = var.github_actions_principal_id
}

resource "azurerm_role_assignment" "gh_user_access_admin" {
  scope                = module.environment.resource_group_id
  role_definition_name = "User Access Administrator"
  principal_id         = var.github_actions_principal_id
}
