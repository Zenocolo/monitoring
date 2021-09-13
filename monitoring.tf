# Variables
resource "random_string" "rand" {
  length  = 6
  special = false
  upper   = false
  number  = false
}

# Locals
locals {
  prefix            = "eu"
  tags = {
    environment = local.prefix
  }
}

# Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.prefix}${random_string.rand.result}"
  location             = var.location
  resource_group_name  = var.rg-name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# Automation Account (patch management)
resource "azurerm_automation_account" "aa" {
  name                = "aa-${local.prefix}-${random_string.rand.result}"
  location             = var.location
  resource_group_name  = var.rg-name
  sku_name            = "Basic"
  tags                = local.tags
}

# Log Analytics Account (monitoring)
resource "azurerm_log_analytics_workspace" "la" {
  name                = "la-${local.prefix}-${random_string.rand.result}"
  location             = var.location
  resource_group_name  = var.rg-name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_linked_service" "aa-la-link" {
  resource_group_name  = var.rg-name
  workspace_id        = azurerm_log_analytics_workspace.la.id
  read_access_id      = azurerm_automation_account.aa.id
}

resource "azurerm_log_analytics_solution" "la_solution_updates" {
  resource_group_name = data.azurerm_resource_group.project.name
  location            = data.azurerm_resource_group.project.location

  solution_name         = "Updates"
  workspace_resource_id = azurerm_log_analytics_workspace.la.id
  workspace_name        = azurerm_log_analytics_workspace.la.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }
}

resource "azurerm_log_analytics_solution" "changeTrackingSolution" {
  solution_name         = "ChangeTracking"
  resource_group_name   = data.azurerm_resource_group.project.name
  location              = data.azurerm_resource_group.project.location
  workspace_resource_id = azurerm_log_analytics_workspace.la.id
  workspace_name        = azurerm_log_analytics_workspace.la.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ChangeTracking"
  }
}

# Send logs to Log Analytics
# Required for automation account with update management and/or change tracking enabled.
# Optional on automation accounts used of other purposes.
resource "azurerm_monitor_diagnostic_setting" "aa_diags_logs" {
  name                       = "LogsToLogAnalytics"
  target_resource_id         = azurerm_automation_account.aa.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id

  log {
    category = "JobLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "JobStreams"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "DscNodeStatus"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      enabled = false
    }
  }
}

# Send metrics to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "aa_diags_metrics" {
  name                       = "MetricsToLogAnalytics"
  target_resource_id         = azurerm_automation_account.aa.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id

  log {
    category = "JobLogs"
    enabled  = false

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "JobStreams"
    enabled  = false

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "DscNodeStatus"
    enabled  = false

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_virtual_machine_extension" "mma_win" {
  count                      = 2
  name                       = "OMSExtension"
  virtual_machine_id         = element(module.vm.virtual_machine_ids, count.index)
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = <<-BASE_SETTINGS
 {
   "workspaceId" : "${azurerm_log_analytics_workspace.la.workspace_id}"
 }
 BASE_SETTINGS

  protected_settings = <<-PROTECTED_SETTINGS
 {
   "workspaceKey" : "${azurerm_log_analytics_workspace.la.primary_shared_key}"
 }
 PROTECTED_SETTINGS
}
