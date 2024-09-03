variable "datacenters" {
  description = "A list of datacenters in the region which are eligible for task placement."
  type        = list(string)
  default     = ["dc1"]
}

variable "region" {
  description = "The region where the job should be placed."
  type        = string
  default     = "global"
}

variable "public_api_version" {
  description = "Docker version tag"
  default = "v0.0.7"
}

variable "product_api_version" {
  description = "Docker version tag"
  default = "v0.0.21"
}

variable "postgres_db" {
  description = "Postgres DB name"
  default = "products"
}

variable "postgres_user" {
  description = "Postgres DB User"
  default = "postgres"
}

variable "postgres_password" {
  description = "Postgres DB Password"
  default = "password"
}

variable "product_api_port" {
  description = "Product API Port"
  default = 9090
}


# Begin Job Spec

job "hashicups-product-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters


  group "product-api" {
    network {
      port "product-api" {
        static = var.product_api_port
      }
    }
    task "product-api" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      driver = "docker"
      service {
        name = "product-api"
        provider = "consul"
        port = "product-api"
      }
      meta {
        service = "product-api"
      }
      config {
        image   = "hashicorpdemoapp/product-api:${var.product_api_version}"
        ports = ["product-api"]
      }
      template {
        data        = <<EOH
{{ range service "database" }}
DB_CONNECTION="host={{ .Address }} port={{ .Port }} user=${var.postgres_user} password=${var.postgres_password} dbname=${var.postgres_db} sslmode=disable"
BIND_ADDRESS = "{{ env "NOMAD_IP_product-api" }}:${var.product_api_port}"
{{ end }}
EOH
        destination = "local/env.txt"
        env         = true
      }
    }
  }

}