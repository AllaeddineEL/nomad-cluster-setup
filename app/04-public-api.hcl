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

variable "public_api_port" {
  description = "Public API Port"
  default = 8081
}
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "backend-team"
}
# Begin Job Spec

job "public-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace   = var.nomad_ns
  group "public-api" {
    network {
      port "public-api" {
        #static = var.public_api_port
      }
    }
    task "public-api" {
      driver = "docker"
      service {
        name = "public-api"
        provider = "consul"
        port = "public-api"
      #  address  = attr.unique.platform.aws.public-ipv4
      }
      meta {
        service = "public-api"
      }
      config {
        image   = "hashicorpdemoapp/public-api:${var.public_api_version}"
        ports = ["public-api"] 
      }
      template {
        data        = <<EOH
BIND_ADDRESS = ":{{ env NOMAD_PORT_public-api }}"
{{ range service "product-api" }}
PRODUCT_API_URI = "http://{{ .Address }}:{{ .Port }}"
{{ end }}
{{ range service "payments-api" }}
PAYMENT_API_URI = "http://{{ .Address }}:{{ .Port }}"
{{ end }}
EOH
        destination = "local/env.txt"
        env         = true
      }
    }
  }

}