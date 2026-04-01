terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "null_resource" "create_data_folder" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/data && chmod 700 ${path.module}/data"
  }
}

resource "docker_network" "postgres_network" {
  name = "postgres_network"
}

resource "docker_container" "postgres" {
  name  = var.container_name
  image = "postgres:${var.postgres_version}"

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.postgres_network.name
  }

  ports {
    internal = 5432
    external = var.port
  }

  env = [
    "POSTGRES_PASSWORD=bootstrap-only"
  ]

  volumes {
    host_path      = abspath("${path.module}/data") # must be absolute
    container_path = "/var/lib/postgresql/data"
  }

}
