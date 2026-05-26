variable "job_name" {
  type        = string
  description = "Name of the ACA Job resource"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "aca_env_id" {
  type        = string
  description = "Resource ID of the Container App Environment to host the runner job"
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
  description = "GitHub classic PAT with repo scope — used for KEDA scaling and JIT runner registration"
}

variable "environment" {
  type        = string
  description = "Environment label applied to the runner (e.g. 'dev') — used as a GitHub runner label"
}

variable "runner_labels" {
  type        = string
  description = "Comma-separated runner labels that KEDA watches (e.g. 'self-hosted,azure,dev')"
  default     = "self-hosted,azure"
}

variable "max_concurrent_runners" {
  type        = number
  description = "Maximum number of runner job instances that can run in parallel"
  default     = 5
}

variable "cpu" {
  type        = number
  description = "CPU cores allocated per runner instance"
  default     = 2.0
}

variable "memory" {
  type        = string
  description = "Memory allocated per runner instance (e.g. '4Gi')"
  default     = "4Gi"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
