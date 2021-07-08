variable "location" {
  type        = string
  description = "The Azure region for the resources (e.g. uksouth)"
}
variable "network_resource_group_name" {
  type        = string
  description = "The name of the resource group where the network is located. This is different as we use a VPN or an agent in the network to deploy the solution and thus restrict public access."
}
variable "vnet_name" {
  type = string
}
variable "gateway_public_ip_name" {
  type = string
}
variable "front_end_address_space" {
  type = string
}
variable "vpn_client_address_space" {
  type = list(string)
}
variable "cert_organisation" {
  type = string
}
variable "tags" {
}
