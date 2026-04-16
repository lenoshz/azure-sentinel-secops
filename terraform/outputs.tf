# =============================================================================
# outputs.tf — Exported values from the Sentinel SecOps Lab deployment
# =============================================================================
# These outputs provide quick reference to key resource identifiers after a
# successful terraform apply.
# =============================================================================

output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.main.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.sentinel.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace (used in KQL and Sentinel)."
  value       = azurerm_log_analytics_workspace.sentinel.name
}

output "sentinel_workspace_name" {
  description = "Same as log_analytics_workspace_name — Sentinel is onboarded here."
  value       = azurerm_log_analytics_workspace.sentinel.name
}

output "vm_public_ip" {
  description = "Public IP address of the honeypot VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "key_vault_uri" {
  description = "URI of the Key Vault storing sensitive secrets."
  value       = azurerm_key_vault.main.vault_uri
}

output "storage_account_name" {
  description = "Name of the storage account for log archival."
  value       = azurerm_storage_account.logs.name
}
