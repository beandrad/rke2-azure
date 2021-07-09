terraform {
  required_providers {
    azurerm = {
      version = "~>2.66.0"
      source  = "hashicorp/azurerm"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>3.1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  tags = {
    "Environment" = var.cluster_name,
    "Terraform"   = "true",
  }
}

resource "azurerm_resource_group" "rke2" {
  name     = var.cluster_name
  location = var.location
}

resource "azurerm_virtual_network" "rke2" {
  name          = "${var.cluster_name}-vnet"
  address_space = ["10.0.0.0/16"]

  resource_group_name = azurerm_resource_group.rke2.name
  location            = azurerm_resource_group.rke2.location

  tags = local.tags
}

resource "azurerm_subnet" "rke2" {
  name = "${var.cluster_name}-snet"

  resource_group_name  = azurerm_resource_group.rke2.name
  virtual_network_name = azurerm_virtual_network.rke2.name

  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_nat_gateway" "rke2" {
  name = "${var.cluster_name}-nat-gw"

  resource_group_name = azurerm_resource_group.rke2.name
  location            = azurerm_resource_group.rke2.location

  sku_name = "Standard"

  tags = local.tags
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "rke2" {
  nat_gateway_id      = azurerm_nat_gateway.rke2.id
  public_ip_prefix_id = azurerm_public_ip_prefix.rke2.id
}

resource "azurerm_subnet_nat_gateway_association" "rke2" {
  subnet_id      = azurerm_subnet.rke2.id
  nat_gateway_id = azurerm_nat_gateway.rke2.id
}

resource "azurerm_public_ip_prefix" "rke2" {
  name = "${var.cluster_name}-nat-pips"

  resource_group_name = azurerm_resource_group.rke2.name
  location            = azurerm_resource_group.rke2.location

  prefix_length = 30

  sku = "Standard"

  tags = local.tags
}

module "rke2_cluster" {
  source              = "./modules/rke2-cluster"
  cluster_name        = var.cluster_name
  resource_group_name = azurerm_resource_group.rke2.name
  vnet_id             = azurerm_virtual_network.rke2.id
  snet_id             = azurerm_subnet.rke2.id
  vnet_name           = azurerm_virtual_network.rke2.name
  snet_name           = azurerm_subnet.rke2.name
  service_principal   = var.service_principal
  cloud = var.cloud
  tags                = local.tags

  depends_on = [
    azurerm_resource_group.rke2
  ]
}

module "vpn_gateway" {
  source                      = "./modules/vpn-gateway"
  location                    = var.location
  network_resource_group_name = azurerm_resource_group.rke2.name
  tags                        = local.tags
  vnet_name                   = azurerm_virtual_network.rke2.name
  gateway_public_ip_name      = "${var.cluster_name}-gateway-ip"
  front_end_address_space     = "10.0.12.0/24"
  vpn_client_address_space    = ["10.20.2.0/29"]
  cert_organisation           = "az dev"
}
