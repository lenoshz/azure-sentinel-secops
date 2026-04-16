# =============================================================================
# defender.tf — Microsoft Defender for Cloud configuration
# =============================================================================
# Enables Defender for Cloud (Free tier) for Virtual Machines, links it to the
# Log Analytics workspace, and configures a security contact for alert
# notifications.
# =============================================================================

# ── Defender for Cloud: VirtualMachines Plan (Free Tier) ─────────────────────

resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = "Free"
  resource_type = "VirtualMachines"
}

# ── Defender for Cloud: Link to Log Analytics Workspace ──────────────────────

resource "azurerm_security_center_workspace" "main" {
  scope        = data.azurerm_subscription.current.id
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

# ── Defender for Cloud: Security Contact ─────────────────────────────────────

resource "azurerm_security_center_contact" "main" {
  email               = var.budget_alert_email
  phone               = "+1-555-0100"
  alert_notifications = true
  alerts_to_admins    = true
}
