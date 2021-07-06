variable "cluster_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "vnet_id" {
  type = string
}
variable "snet_id" {
    type = string
}
variable "vnet_name" {
  type = string
}
variable "snet_name" {
    type = string
}
variable "service_principal" {
  type = object({
    client_id = string
    client_secret = string
  })
}
variable "vm_size" {
  type = string
  default = "Standard_DS4_v2"
}
variable "vm_count" {
  type = number
  default = 1
}

variable "tags" {
  type = object({})
  default = {}
}
