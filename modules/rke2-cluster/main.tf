locals {
  nodepool_nsgs = [module.rke2.network_security_group_name]
}

resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_network_security_group" "k8s" {
  name = "${var.cluster_name}-k8s-nsg"

  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  tags = merge({}, var.tags)
}

module "rke2" {
  source = "../rke2-server"

  cluster_name        = var.cluster_name
  resource_group_name = var.resource_group_name

  virtual_network_id = var.vnet_id
  subnet_id          = var.snet_id
  virtual_network_name = var.vnet_name
  subnet_name          = var.snet_name
  k8s_nsg_name       = azurerm_network_security_group.k8s.name

  service_principal = var.service_principal

  admin_ssh_public_key = tls_private_key.default.public_key_openssh

  servers = var.vm_count
  vm_size = var.vm_size
  priority = "Spot"

  enable_ccm = true
  cloud = var.cloud

  tags = var.tags
}

module "generic_agents" {
  source       = "../rke2-agents"
  cluster_data = module.rke2.cluster_data

  name                = "generic"
  resource_group_name = var.resource_group_name

  virtual_network_id = var.vnet_id
  subnet_id          = var.snet_id
  virtual_network_name = var.vnet_name
  subnet_name          = var.snet_name
  k8s_nsg_name       = azurerm_network_security_group.k8s.name

  service_principal = var.service_principal

  admin_ssh_public_key = tls_private_key.default.public_key_openssh

  instances = 1
  vm_size = var.vm_size
  priority  = "Spot"
  cloud = var.cloud

  tags = var.tags
}

resource "azurerm_key_vault_secret" "node_key" {
  name         = "node-key"
  value        = tls_private_key.default.private_key_pem
  key_vault_id = module.rke2.cluster_data.token.vault_id
}

resource "local_file" "node_private_key" {
  content  = tls_private_key.default.private_key_pem
  filename = ".ssh/rk2_id_rsa"
}

resource "local_file" "node_public_key" {
  content  = tls_private_key.default.public_key_openssh
  filename = ".ssh/rk2_id_rsa.pub"
}


# Dev/Example settings only

# Open up ssh on all the nodepools
resource "azurerm_network_security_rule" "ssh" {
  count = length(local.nodepool_nsgs)

  name                        = "${var.cluster_name}-ssh"
  access                      = "Allow"
  direction                   = "Inbound"
  network_security_group_name = local.nodepool_nsgs[count.index]
  priority                    = 201
  protocol                    = "Tcp"
  resource_group_name         = var.resource_group_name

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_address_prefix = "*"
  destination_port_range     = "22"
}

# Example method of fetching kubeconfig from state store, requires azure cli and bash locally
resource "null_resource" "kubeconfig" {
  depends_on = [module.rke2]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "az keyvault secret show --name kubeconfig --vault-name ${module.rke2.token_vault_name} | jq -r '.value' > rke2.kubeconfig"
  }
}
