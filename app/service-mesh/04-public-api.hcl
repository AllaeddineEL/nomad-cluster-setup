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
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "backend-team"
}
variable "product_api_port" {
  description = "Product API Port"
  default = 9090
}

variable "frontend_port" {
  description = "Frontend Port"
  default = 3000
}

variable "payments_api_port" {
  description = "Payments API Port"
  default = 8080
}

variable "public_api_port" {
  description = "Public API Port"
  default = 8081
}

variable "nginx_port" {
  description = "Nginx Port"
  default = 80
}

variable "db_port" {
  description = "Postgres Database Port"
  default = 5432
}
# Begin Job Spec

job "public-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace   = var.nomad_ns
  group "public-api" {
    count = 1
    network {
      mode = "bridge"
    }
    service {
        name = "public-api"
        provider = "consul"
        port = "${var.public_api_port}"
        check {
          name      = "Public API ready"
          address_mode = "alloc"
					type      = "http"
          path			= "/health"
					interval  = "5s"
					timeout   = "5s"
        }
        connect {
          sidecar_service {
            proxy {
              upstreams {
                destination_name = "product-api"
                local_bind_port = 9090
              }
              upstreams {
                destination_name = "payments-api"
                local_bind_port = 8080
              }
            }
        }
      }
    }
    task "public-api" {
      driver = "docker"
      meta {
        service = "public-api"
      }
      config {
        image   = "hashicorpdemoapp/public-api:${var.public_api_version}"
        ports = ["${var.public_api_port}"] 
      }
      env {
        BIND_ADDRESS = ":${var.public_api_port}"
        PRODUCT_API_URI = "http://127.0.0.1:${var.product_api_port}"
        PAYMENT_API_URI = "http://127.0.0.1:${var.payments_api_port}"
      }
    }
  }

}