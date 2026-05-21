terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Pull Mailpit image
resource "docker_image" "mailpit" {
  name = "axllent/mailpit:latest"
}

# Run Mailpit container
resource "docker_container" "mailpit" {
  name  = "mailpit"
  image = docker_image.mailpit.image_id

  ports {
    internal = 1025
    external = 1025
  }

  ports {
    internal = 8025
    external = 8025
  }

  restart = "unless-stopped"
}
