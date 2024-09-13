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

variable "product_api_port" {
  description = "Product API Port"
  default = 9090
}
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "backend-team"
}

# Begin Job Spec

job "product-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace   = var.nomad_ns

  group "product-api" {
    network {
      port "product-api" {
       # static = var.product_api_port
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
       vault {
        role = "postgressql-dynamic-secret"
      }
      config {
        image   = "hashicorpdemoapp/product-api:${var.product_api_version}"
        ports = ["product-api"]
      }
      template {
        data        = <<EOH
{{ range service "product-api-db" }}
DB_CONNECTION="host={{ .Address }} port={{ .Port }} user={{with secret "database/creds/product-api-db-ro"}}{{.Data.username}}{{end}} password={{with secret "database/creds/product-api-db-ro"}}{{.Data.password}}{{end}} dbname=${var.postgres_db} sslmode=disable"
BIND_ADDRESS = "{{ env "NOMAD_IP_product-api" }}:{{ env "NOMAD_PORT_product-api" }}"
{{ end }}
EOH
        destination = "local/env.txt"
        env         = true
      }
    }
  }

}