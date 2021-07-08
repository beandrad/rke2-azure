output "rke2_cluster" {
  value = module.rke2_cluster.cluster_data
}

output "kv_name" {
  value = module.rke2_cluster.token_vault_name
}

output "rg_name" {
  value = azurerm_resource_group.rke2.name
}

output "client_cert" {
  value     = module.vpn_gateway.client_cert
  sensitive = true
}

output "client_key" {
  value     = module.vpn_gateway.client_key
  sensitive = true
}

output "vpn_gateway_id" {
  value = module.vpn_gateway.vpn_id
}

output "vpn_gateway_ip" {
  value = module.vpn_gateway.vpn_ip
}

output "vpn_gateway_name" {
  value = module.vpn_gateway.vpn_name
}
