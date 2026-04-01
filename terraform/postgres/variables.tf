variable "container_name" {
  type    = string
  default = "postgres"
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "port" {
  type    = number
  default = 5432
}
