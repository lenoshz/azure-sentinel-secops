# =============================================================================
# keyvault.tf — Azure Key Vault for secrets management
# =============================================================================
# Provisions a Key Vault with purge protection, soft-delete, and RBAC
# authorization.  Stores a randomly generated VM admin password and grants the
# deploying user the Key Vault Secrets Officer role.
# =============================================================================

# ── Random Password ──────────────────────────────────────────────────────────

resource "random_password" "vm_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%^&*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ── Key Vault ────────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "main" {
  name                          = "${var.prefix}-kv-${random_string.suffix.result}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  enable_rbac_authorization     = true
  enabled_for_deployment        = true
  enabled_for_template_deployment = true
  tags                          = var.tags

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# ── Store VM Admin Password as Secret ────────────────────────────────────────

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_admin.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}

# ── RBAC: Grant deploying user Key Vault Secrets Officer ─────────────────────

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
