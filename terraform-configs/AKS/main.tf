# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.48.0"
    }
  }
}

# Configure the Azure provider
provider "azurerm" {
  features {}
}

# Create a resource group for the AKS cluster
resource "azurerm_resource_group" "aks_rg" {
  name     = var.rg_name
  location = var.location
}

# Create the AKS cluster
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku_tier            = "Paid"
  kubernetes_version  = "1.24" # Specify Kubernetes version
  dns_prefix          = "devtron-prod"

  default_node_pool {
    name                         = "defaultpool"
    node_count                   = 1
    vm_size                      = "Standard_DS2_v2"
    os_disk_size_gb              = 30
    vnet_subnet_id               = azurerm_subnet.aks_subnet.id
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 5
    only_critical_addons_enabled = true
    max_pods_per_node             = 30
  }

  linux_profile {
    admin_username = "ubuntu"
    ssh_key {
      key_data = "ssh-rsa <key-here>"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
    }
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    load_balancer_sku = "standard"
  }

  tags = {
    Environment = "Production"
  }
}

# Create the AKS subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = ["10.0.0.0/16"]
}

# Create the AKS virtual network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "aks-vnet"
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Create the log analytics workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "log-analytics"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = "PerGB2018"
}

# Create the storage account for blob storage
resource "azurerm_storage_account" "devtron_blob_storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Environment = "Production"
  }
}
