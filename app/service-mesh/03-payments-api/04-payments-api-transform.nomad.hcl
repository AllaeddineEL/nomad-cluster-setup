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
  default = "v0.0.16"
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

job "payments-api" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace   = var.nomad_ns

  group "payments-api" {
    count = 1
    network {
      mode = "bridge"
    }
    service {
      name = "payments-api"
      provider = "consul"
      port = "${var.payments_api_port}"

      connect {
        sidecar_service {
          proxy {
            transparent_proxy {
            }
          }
        }
      }

      check {
        name      = "Payments API ready"
        address_mode = "alloc"
        type      = "http"
        path			= "/actuator/health"
        interval  = "5s"
        timeout   = "5s"
        expose   = true
      }
    }
    task "payments-api" {
      driver = "docker"
      meta {
        service = "payments-api"
      }
      vault {
        role = "payments-transform-secret"
      }
      config {
        image   = "hashicorpdemoapp/payments:${var.payments_version}"
        ports = ["${var.payments_api_port}"]
      }
      resources {
        cpu    = 500
        memory = 500
      }
      env {
        SPRING_CONFIG_LOCATION = "file:/local/"
        SPRING_CLOUD_BOOTSTRAP_LOCATION = "file:/local/"
      }
      template {
        data = <<EOF
server.port=${var.payments_api_port}        
app.storage=db
app.encryption.enabled=true
app.encryption.path=transform
app.encryption.key=payments
EOF
        destination = "local/application.properties"
      }
      # Creation of the template file defining how to connect to vault
      template {
        destination   = "local/bootstrap.yml"
        data = <<EOF
spring:
  cloud:
    vault:
      enabled: true
      fail-fast: true
      authentication: NONE
      {{ range service "product-api-db" }}
      host: server-a-1
      port: 8200
      scheme: http
      kv:
        enabled: false
      generic:
        enabled: false
EOF
      }
      template {
        destination   = "local/application.yaml"
        data = <<EOF
spring:
  application:
    name: payments-api
  datasource:
    url: jdbc:h2:mem:testdb
    driverClassName: org.h2.Driver
    username: sa
    password: password
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    show-sql: true
  h2:
    console:
      enabled: true
      settings:
        web-allow-others: true
management:
  endpoint:
    health:
      show-details: always
EOF
    }
  }

}