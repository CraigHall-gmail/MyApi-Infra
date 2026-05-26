resource_group = "rg-myapi-dev"
aca_name_env   = "aca-myapi-dev"
law_name_env   = "law-myapi-dev"
location       = "southafricanorth"

acr_name           = "acrimagereg"
acr_resource_group = "Playground"
app_name           = "myapi-dev"

cpu          = 0.25
memory       = "0.5Gi"
min_replicas = 1
max_replicas = 3

tags = {
  project     = "myapi"
  environment = "dev"
  managed_by  = "terraform"
}

# PostgreSQL — pg_admin_password is supplied via TF_VAR_pg_admin_password (GitHub Secret)
# Key Vault names must be globally unique across Azure; adjust if taken.
pg_server_name          = "psql-myapi-dev"
pg_key_vault_name       = "kv-myapi-dev"
pg_sku_name             = "B_Standard_B1ms"
pg_geo_redundant_backup = false # Burstable SKU does not support geo-redundant backups

github_actions_principal_id = "6eba19ed-4ad3-4380-93ba-e99d0563b1ab"
pg_storage_mb               = 32768

# VNet — subnets are hardcoded in main.tf; only the top-level CIDR is variable
vnet_address_space = "10.0.0.0/16"

# GitHub runner — runner_pat is supplied via TF_VAR_runner_pat (GitHub Secret)
github_org = "CraigHall-gmail"
