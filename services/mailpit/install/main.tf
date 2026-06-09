terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "mailpit" {
  name         = "axllent/mailpit:latest"
  keep_locally = false
}

resource "docker_container" "mailpit" {
  name  = "mailpit"
  image = docker_image.mailpit.image_id

  restart = "unless-stopped"

  ports {
    internal = 1025
    external = 1025
  }

  ports {
    internal = 8025
    external = 8025
  }
}
