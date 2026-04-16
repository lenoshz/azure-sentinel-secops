# =============================================================================
# main.tf — Core infrastructure for the Azure Sentinel SecOps Lab
# =============================================================================
# Deploys: Resource Group, Log Analytics + Sentinel, VNet/Subnet/NSG, Linux VM
# with auto-shutdown, Storage Account, Diagnostic Settings, Sentinel data
# connectors, and a Consumption Budget.
# =============================================================================

# ── Data Sources ─────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# ── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ── Log Analytics Workspace ──────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = "${var.prefix}-law-sentinel"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ── Microsoft Sentinel ───────────────────────────────────────────────────────

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id                 = azurerm_log_analytics_workspace.sentinel.id
  customer_managed_key_enabled = false
}

# ── Virtual Network ──────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "${var.prefix}-snet-workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ── Network Security Group ───────────────────────────────────────────────────

resource "azurerm_network_security_group" "workload" {
  name                = "${var.prefix}-nsg-workload"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # Deny all inbound by default (explicit low-priority rule)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow SSH only from approved IP ranges
  security_rule {
    name                       = "AllowSSHFromApproved"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ip_ranges
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

# ── Public IP for VM ─────────────────────────────────────────────────────────

resource "azurerm_public_ip" "vm" {
  name                = "${var.prefix}-pip-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ── Network Interface ────────────────────────────────────────────────────────

resource "azurerm_network_interface" "vm" {
  name                = "${var.prefix}-nic-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# ── Linux Virtual Machine ────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "honeypot" {
  name                            = "${var.prefix}-vm-honeypot"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.prefix}-osdisk-vm"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# ── VM Auto-Shutdown (19:00 UTC daily) ───────────────────────────────────────

resource "azurerm_dev_test_global_vm_shutdown_schedule" "honeypot" {
  virtual_machine_id    = azurerm_linux_virtual_machine.honeypot.id
  location              = azurerm_resource_group.main.location
  enabled               = true
  daily_recurrence_time = "1900"
  timezone              = "UTC"
  tags                  = var.tags

  notification_settings {
    enabled = false
  }
}

# ── Storage Account ──────────────────────────────────────────────────────────

resource "azurerm_storage_account" "logs" {
  name                            = "${var.prefix}stlogs${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ── Diagnostic Settings: VM → Log Analytics ──────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "vm_diagnostics" {
  name                       = "${var.prefix}-diag-vm"
  target_resource_id         = azurerm_linux_virtual_machine.honeypot.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ── Diagnostic Settings: Activity Logs → Log Analytics ───────────────────────

resource "azurerm_monitor_diagnostic_setting" "activity_logs" {
  name                       = "${var.prefix}-diag-activity"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Policy"
  }
}

# ── Diagnostic Settings: NSG Flow Logs → Log Analytics ───────────────────────

resource "azurerm_monitor_diagnostic_setting" "nsg_diagnostics" {
  name                       = "${var.prefix}-diag-nsg"
  target_resource_id         = azurerm_network_security_group.workload.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# ── Sentinel Data Connector: Azure Active Directory ──────────────────────────

resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  name                       = "${var.prefix}-dc-aad"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.sentinel.workspace_id
}

# ── Consumption Budget ───────────────────────────────────────────────────────

resource "azurerm_consumption_budget_resource_group" "lab_budget" {
  name              = "${var.prefix}-budget-monthly"
  resource_group_id = azurerm_resource_group.main.id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = [var.budget_alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"

    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
