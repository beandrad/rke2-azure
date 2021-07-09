variable "cluster_name" {
  type = string
}

variable "location" {
  type    = string
  default = "usgovvirginia"
}

variable "cloud" {
  type = string
  default = "AzureUSGovernmentCloud"
  validation {
    condition     = contains(["AzureUSGovernmentCloud", "AzurePublicCloud"], var.cloud)
    error_message = "Allowed values for cloud are \"AzureUSGovernmentCloud\" or \"AzurePublicCloud\"."
  }
}

variable "service_principal" {
  type = object({
    client_id     = string
    client_secret = string
  })
}
