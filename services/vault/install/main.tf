terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "vault" {
  name         = "hashicorp/vault:latest"
  keep_locally = true
}

resource "docker_container" "vault" {
  name  = "vault"
  image = docker_image.vault.image_id

  restart = "unless-stopped"

  ports {
    internal = 8200
    external = 8200
  }

  volumes {
    host_path      = abspath("${path.module}/config")
    container_path = "/vault/config"
  }

  volumes {
    host_path      = pathexpand(var.data_dir)
    container_path = "/vault/data"
  }

  capabilities {
    add = ["IPC_LOCK"]
  }

  command = ["vault", "server", "-config=/vault/config/vault-config.json"]

  env = [
    "VAULT_ADDR=http://127.0.0.1:8200",
    "VAULT_API_ADDR=http://127.0.0.1:8200"
  ]
}
