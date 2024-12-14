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
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "frontend-team"
}
variable "product_api_port" {
  description = "Product API Port"
  default = 9090
}

variable "frontend_port" {
  description = "Frontend Port"
  default = 80
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

job "frontend" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace = var.nomad_ns
  group "frontend" {
    count = 1
    network {
      mode = "bridge"
    }
    service {
      name = "frontend"
      provider = "consul"
      port = "${var.frontend_port}"
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {
            }
          }
        }
      }
      check {
        name      = "Frontend ready"
        address_mode = "alloc"
        type      = "http"
        path      = "/health"
        interval  = "5s"
        timeout   = "5s"
        expose   = true
      }
    }
    task "frontend" {
      driver = "docker"
      meta {
        service = "frontend"
      }
      config {
        image = "hashicorpdemoapp/frontend-nginx:v1.0.9"
        ports = ["${var.frontend_port}"]
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      env {
          NEXT_PUBLIC_FOOTER_FLAG = "HashiCups instance ${NOMAD_ALLOC_INDEX}"
          NEXT_PUBLIC_PUBLIC_API_URL="/"
          PORT="${var.frontend_port}"
      }
      template {
        data =  <<EOF
server {
  listen 80;
  server_name localhost;
  server_tokens off;
  gzip on;
  gzip_proxied any;
  gzip_comp_level 4;
  gzip_types text/css application/javascript image/svg+xml;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection 'upgrade';
  proxy_set_header Host $host;
  proxy_cache_bypass $http_upgrade;
  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
  }
  location  /health {
               access_log off;
               add_header 'Content-Type' 'application/json';
               return 200 '{"status":"UP"}';
              }
  location /api {
      proxy_pass http://public-api.virtual.global:${var.public_api_port};
  }
}
        EOF
        destination = "local/default.conf"
      }
      
    }
  }
}