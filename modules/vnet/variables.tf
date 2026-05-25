variable "vnet_name" {
  type        = string
  description = "Name of the Virtual Network"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "address_space" {
  type        = string
  description = "CIDR block for the VNet (e.g. '10.0.0.0/16')"
}

variable "aca_subnet_cidr" {
  type        = string
  description = "CIDR for ACA environment subnet — minimum /23 for consumption workload profile"
}

variable "postgres_subnet_cidr" {
  type        = string
  description = "CIDR for PostgreSQL Flexible Server delegated subnet"
}

variable "private_endpoints_subnet_cidr" {
  type        = string
  description = "CIDR for private endpoints subnet (Key Vault NIC)"
}

variable "runner_subnet_cidr" {
  type        = string
  description = "CIDR for self-hosted ACA Jobs runner subnet — /27 is sufficient"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
