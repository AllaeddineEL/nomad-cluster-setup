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

variable "frontend_version" {
  description = "Docker version tag"
  default = "v1.0.4"
}

variable "frontend_port" {
  description = "Frontend Port"
  default = 3000
}
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "frontend-team"
}
# Begin Job Spec

job "frontend" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace = var.nomad_ns

  group "frontend" {
    network {
      port "frontend" {
       # static = var.frontend_port
      }
    }
    task "frontend" {
      driver = "docker"
      service {
        name = "frontend"
        provider = "consul"
        port = "frontend"
       # address  = attr.unique.platform.aws.public-ipv4
      }
      meta {
        service = "frontend"
      }
      template {
        data        = <<EOH
{{ range service "public-api" }}
NEXT_PUBLIC_PUBLIC_API_URL="http://{{ .Address }}:{{ .Port }}"
NEXT_PUBLIC_FOOTER_FLAG="{{ env "NOMAD_ALLOC_NAME" }}"
{{ end }}
PORT="{{ env "NOMAD_PORT_frontend" }}"
EOH
        destination = "local/env.txt"
        env         = true
      }
      config {
        image   = "hashicorpdemoapp/frontend:${var.frontend_version}"
        ports = ["frontend"]
      }
    }
  }

}