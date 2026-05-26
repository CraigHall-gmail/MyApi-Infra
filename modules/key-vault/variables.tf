variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault (globally unique, 3–24 alphanumeric/hyphen chars)"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "secret_name" {
  type        = string
  description = "Name of the secret to store in the Key Vault"
  default     = "db-connection-string"
}

variable "secret_value" {
  type        = string
  sensitive   = true
  description = "Value of the secret to store"
}

variable "secret_expiry_duration" {
  type        = string
  description = "TTL for the Key Vault secret from the time of last apply (e.g. '8760h' = 1 year). The secret expiration is extended each time terraform apply runs, so this is effectively a maximum drift window between applies before the secret expires."
  default     = "8760h"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the Key Vault private endpoint NIC. Null = no private endpoint (public access via network ACL bypass)."
  default     = null
}

variable "private_dns_zone_id" {
  type        = string
  description = "Resource ID of the privatelink.vaultcore.azure.net private DNS zone. Required when private_endpoint_subnet_id is set."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
