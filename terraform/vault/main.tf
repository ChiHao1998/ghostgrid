terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "docker" {}
provider "local" {}

# Write vault-config.json dynamically from variables
resource "local_file" "vault_config" {
  filename = "${path.module}/config/vault-config.json"
  content  = <<EOT
{
  "storage": {
    "file": {
      "path": "${var.vault_storage_path}"
    }
  },
  "listener": [
    {
      "tcp": {
        "address": "${var.vault_listener_address}",
        "tls_disable": ${var.vault_tls_disable}
      }
    }
  ],
  "ui": ${var.vault_ui}
}
EOT
}

resource "docker_image" "vault" {
  name = "hashicorp/vault:latest"
}

resource "docker_container" "vault" {
  name  = "vault"
  image = docker_image.vault.image_id

  ports {
    internal = 8200
    external = 8200
  }

  # Mount config directory
  volumes {
    host_path      = abspath("${path.module}/config")
    container_path = "/vault/config"
  }

  # Mount data directory
  volumes {
    host_path      = abspath("${path.module}/data")
    container_path = "/vault/data"
  }

  capabilities {
    add = ["IPC_LOCK"]
  }

  # Run Vault in server mode using the generated config
  command = ["server", "-config=/vault/config/vault-config.json"]

  env = [
    "VAULT_ADDR=${var.vault_addr}",
    "VAULT_API_ADDR=${var.vault_addr}"
  ]

  restart = "no"

  depends_on = [local_file.vault_config]
}

output "vault_container_name" {
  description = "The name of the Vault container"
  value       = docker_container.vault.name
}

output "vault_ui_url" {
  description = "Vault UI URL"
  value       = var.vault_addr
}
