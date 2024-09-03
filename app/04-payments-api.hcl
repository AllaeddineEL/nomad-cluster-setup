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

variable "payments_version" {
  description = "Docker version tag"
  default = "v0.0.12"
}

variable "payments_api_port" {
  description = "Payments API Port"
  default = 8080
}

# Begin Job Spec

job "hashicups-payments-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters


  group "payments-api" {
    network {
      port "payments-api" {
        static = var.payments_api_port
      }
    }
    task "payments-api" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      driver = "docker"
      service {
        name = "payments-api"
        provider = "consul"
        port = "payments-api"
      }
      meta {
        service = "payments-api"
      }
      config {
        image   = "hashicorpdemoapp/payments:${var.payments_version}"
        ports = ["payments-api"]
        mount {
          type   = "bind"
          source = "local/application.properties"
          target = "/application.properties"
        }
      }
      template {
        data = "server.port=${var.payments_api_port}"
        destination = "local/application.properties"
      }
    }
  }

}