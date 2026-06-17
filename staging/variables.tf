variable "resource_group" {
  type        = string
  description = "Name of the Azure resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southafricanorth"
}

variable "aca_name_env" {
  type        = string
  description = "Name of the Azure Container App Environment"
}

variable "law_name_env" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

variable "acr_name" {
  type        = string
  description = "Name of the existing Azure Container Registry"
}

variable "acr_resource_group" {
  type        = string
  description = "Resource group containing the ACR"
}

variable "app_name" {
  type        = string
  description = "Name of the Container App"
}

variable "cpu" {
  type        = number
  description = "CPU allocation for the container"
  default     = 0.5
}

variable "memory" {
  type        = string
  description = "Memory allocation for the container (e.g. '1Gi')"
  default     = "1Gi"
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of replicas"
  default     = 1
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of replicas"
  default     = 10
}

variable "aspnetcore_environment" {
  type        = string
  description = "ASPNETCORE_ENVIRONMENT injected into the container"
  default     = "Staging"
}

variable "pg_server_name" {
  type        = string
  description = "Name of the PostgreSQL Flexible Server (globally unique)"
}

variable "pg_key_vault_name" {
  type        = string
  description = "Name of the Key Vault (globally unique, 3–24 chars)"
}

variable "pg_admin_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL admin password — injected via TF_VAR_pg_admin_password in CI"
}

variable "pg_sku_name" {
  type        = string
  description = "PostgreSQL SKU (e.g. B_Standard_B2ms)"
  default     = "B_Standard_B2ms"
}

variable "pg_storage_mb" {
  type        = number
  description = "PostgreSQL storage in MB"
  default     = 32768
}

variable "pg_geo_redundant_backup" {
  type        = bool
  description = "Enable geo-redundant backups. Must be false for Burstable SKUs (B_Standard_*)."
  default     = false
}

variable "github_actions_principal_id" {
  type        = string
  description = "Object ID of the GitHub Actions service principal — granted Contributor + User Access Administrator on the resource group"
}

variable "vnet_address_space" {
  type        = string
  description = "CIDR block for the staging VNet"
  default     = "10.1.0.0/16"
}

variable "github_owner" {
  type        = string
  description = "GitHub account or org name (owner of the repository)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name — runners register at repo scope"
}

variable "runner_pat" {
  type        = string
  sensitive   = true
  description = "GitHub classic PAT with repo scope — injected via TF_VAR_runner_pat in CI"
}

variable "runner_app_pat" {
  type        = string
  sensitive   = true
  description = "GitHub classic PAT with repo scope for the application repo (MyApi) — injected via TF_VAR_runner_app_pat in CI"
}
