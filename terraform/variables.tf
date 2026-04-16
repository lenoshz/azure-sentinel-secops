# =============================================================================
# variables.tf — Input variables for the Sentinel SecOps Lab
# =============================================================================
# All configurable values used across the Terraform configuration.  Sensitive
# variables are marked so their values are redacted from plan/apply output.
# =============================================================================

# ── Location & Naming ────────────────────────────────────────────────────────

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "rg-sentinel-secops-lab"
}

variable "prefix" {
  description = "Short prefix prepended to every resource name for uniqueness."
  type        = string
  default     = "secops"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.prefix))
    error_message = "Prefix must be 3-10 lowercase alphanumeric characters."
  }
}

# ── Virtual Machine ──────────────────────────────────────────────────────────

variable "admin_username" {
  description = "Admin username for the Linux virtual machine."
  type        = string
  default     = "azureadmin"
  sensitive   = true
}

variable "admin_ssh_public_key" {
  description = "SSH public key content for VM authentication (contents of ~/.ssh/id_rsa.pub)."
  type        = string
  sensitive   = true
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "allowed_ip_ranges" {
  description = "List of CIDR ranges allowed SSH access to the VM (e.g. your home IP as x.x.x.x/32)."
  type        = list(string)
  default     = []
}

# ── Budget & Alerts ──────────────────────────────────────────────────────────

variable "budget_amount" {
  description = "Monthly budget cap in USD for the resource group."
  type        = number
  default     = 20
}

variable "budget_alert_email" {
  description = "Email address to receive budget and Defender for Cloud alerts."
  type        = string
  sensitive   = true
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Default tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "Lab"
    Project     = "SentinelLab"
    ManagedBy   = "Terraform"
  }
}
