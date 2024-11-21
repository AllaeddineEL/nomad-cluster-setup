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

variable "product_api_db_version" {
  description = "Docker version tag"
  default = "v0.0.22"
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

variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "data-team"
}

# Begin Job Spec

job "product-api-db" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace   = var.nomad_ns

  group "db" {
    count = 1
    network {
      port "db" {
       static = 5432
      }
    }
    service {
      name = "product-api-db"
      provider = "consul"
      port = "db"
      check {
        name      = "Database ready"
        type      = "script"
        command   = "/usr/bin/pg_isready"
        args      = ["-d", "${var.db_port}"]
        interval  = "5s"
        timeout   = "2s"
        on_update = "ignore_warnings"
        task      = "db"
      }
    }
    task "db" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      driver = "docker"
      meta {
        service = "database"
      }
      vault {}
      config {
        image   = "hashicorpdemoapp/product-api-db:${var.product_api_db_version}"
        ports = ["db"]
      }
      template {
        data        = <<EOF
POSTGRES_DB=products        
POSTGRES_USER=postgres
POSTGRES_PASSWORD={{with secret "kv/data/${var.nomad_ns}/product-api-db/config"}}{{.Data.data.root_password}}{{end}}
EOF
        destination = "secrets/env"
        env         = true
      }
    }
  }
}