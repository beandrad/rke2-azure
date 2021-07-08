locals {
  front_end_subnets = cidrsubnets(var.front_end_address_space, 3, 3, 3, 3)
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [local.front_end_subnets.3]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_public_ip" "vpn_ip" {
  name                = var.gateway_public_ip_name
  location            = var.location
  resource_group_name = var.network_resource_group_name
  domain_name_label   = random_string.random.result
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
  timeouts {
    read = "10m"
  }
}

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "vpn_gateway"
  location            = var.location
  resource_group_name = var.network_resource_group_name
  tags                = var.tags
  type                = "Vpn"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw2AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space        = var.vpn_client_address_space
    vpn_client_protocols = ["OpenVPN"]
    root_certificate {
      name             = "terraformselfsignedder"
      public_cert_data = data.local_file.ca_der.content
    }
  }

  depends_on = [azurerm_public_ip.vpn_ip]
}

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
  number  = false
}
