variable "vault_addr" {
  type        = string
  description = "Vault API address"
}

variable "vault_storage_path" {
  type        = string
  description = "Vault storage path"
}

variable "vault_listener_address" {
  type        = string
  description = "Vault listener address"
}

variable "vault_tls_disable" {
  type        = number
  description = "Disable TLS (1 = true, 0 = false)"
}

variable "vault_ui" {
  type        = bool
  description = "Enable Vault UI"
}
