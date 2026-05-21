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

# RabbitMQ image
resource "docker_image" "rabbitmq" {
  name = "rabbitmq:3-management"
}

# Persistent volume
resource "docker_volume" "rabbitmq_data" {
  name = "rabbitmq_data"
}

# RabbitMQ container
resource "docker_container" "rabbitmq" {
  name  = "rabbitmq"
  image = docker_image.rabbitmq.image_id

  ports {
    internal = 5672
    external = 5672
  }

  ports {
    internal = 15672
    external = 15672
  }

  env = [
    "RABBITMQ_DEFAULT_USER=admin",
    "RABBITMQ_DEFAULT_PASS=admin"
  ]

  volumes {
    volume_name    = docker_volume.rabbitmq_data.name
    container_path = "/var/lib/rabbitmq"
  }

  restart = "unless-stopped"
}
