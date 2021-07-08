variable "cluster_name" {
  type = string
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "service_principal" {
  type = object({
    client_id     = string
    client_secret = string
  })
}
