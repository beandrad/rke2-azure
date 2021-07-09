locals {
  name = "${var.cluster_data.name}-${var.name}"

  ccm_tags = {
    "kubernetes.io_cluster_${var.cluster_data.name}" = "owned",
  }
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

#
# Agent Nodepool
#
module "init" {
  source = "../custom_data"

  server_url   = var.cluster_data.server_url
  vault_url    = var.cluster_data.token.vault_url
  token_secret = var.cluster_data.token.token_secret

  config        = var.rke2_config
  pre_userdata  = var.pre_userdata
  post_userdata = var.post_userdata
  ccm           = false
  cloud = var.cloud

  agent = true
}

data "template_cloudinit_config" "init" {
  base64_encode = true

  part {
    filename     = "00_download.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/../common/download.sh", {
      rke2_version = var.rke2_version
      type         = "agent"
    })
  }

  part {
    filename     = "01_rke2.sh"
    content_type = "text/x-shellscript"
    content      = module.init.templated
  }

  part {
    filename     = "azure-cloud.tpl"
    content_type = "text/cloud-config"
    content = jsonencode({
      write_files = [
        {
          content     = "vm.max_map_count=262144"
          path        = "/etc/sysctl.d/10-vm-map-count.conf"
          permissions = "5555"
        },
        {
          content = templatefile("${path.module}/../custom_data/files/azure-cloud.conf.template", {
            tenant_id = data.azurerm_client_config.current.tenant_id
            client_id = var.service_principal.client_id
            client_secret = var.service_principal.client_secret
            subscription_id = data.azurerm_client_config.current.subscription_id
            rg_name = data.azurerm_resource_group.rg.name
            location = data.azurerm_resource_group.rg.location
            subnet_name = var.subnet_name
            virtual_network_name = var.virtual_network_name
            nsg_name = var.k8s_nsg_name
            cloud = var.cloud
          })
          path        = "/etc/rancher/rke2/cloud.conf"
          permissions = "5555"
        }
      ]
    })
  }
}

resource "azurerm_network_security_group" "agent" {
  name = "${local.name}-agent-nsg"

  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  tags = merge({}, var.tags)
}

module "agents" {
  source = "../nodepool"

  name = "${local.name}-agent"

  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_id  = var.virtual_network_id
  subnet_id           = var.subnet_id

  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  vm_size                       = var.vm_size
  instances                     = var.instances
  overprovision                 = var.overprovision
  zones                         = var.zones
  zone_balance                  = var.zone_balance
  single_placement_group        = var.single_placement_group
  upgrade_mode                  = var.upgrade_mode
  priority                      = var.priority
  eviction_policy               = var.priority == "Spot" ? var.eviction_policy : null
  dns_servers                   = var.dns_servers
  enable_accelerated_networking = var.enable_accelerated_networking

  source_image_reference = var.source_image_reference
  assign_public_ips      = var.assign_public_ips
  nsg_id                 = azurerm_network_security_group.agent.id

  identity_ids = [var.cluster_data.cluster_identity_id]
  custom_data  = data.template_cloudinit_config.init.rendered

  os_disk_size_gb              = var.os_disk_size_gb
  os_disk_storage_account_type = var.os_disk_storage_account_type
  os_disk_encryption_set_id    = var.os_disk_encryption_set_id

  additional_data_disks = var.additional_data_disks

  tags = merge({
    "Role" = "agent",
  }, local.ccm_tags, var.tags)
}
