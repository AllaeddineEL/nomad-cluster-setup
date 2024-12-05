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

job "nginx-reverse-proxy" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace = var.nomad_ns
  group "nginx" {
    count = 1
    network {
      mode = "bridge"
      port = "${var.nginx_port}"
    }
    service {
      name = "nginx"
      provider = "consul"
      port = "${var.nginx_port}"
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {
            }
          }
        }
      }
      check {
        name      = "NGINX ready"
        type      = "http"
        path			= "/health"
        interval  = "5s"
        timeout   = "5s"
      }
    }
    task "nginx" {
      driver = "docker"
      meta {
        service = "nginx-reverse-proxy"
      }
      config {
        image = "nginx:alpine"
        ports = ["nginx"]
        network_mode = "host"
        mount {
          type   = "bind"
          source = "local/nginx.conf"
          target = "/etc/nginx/conf.d/nginx.conf"
        }
      }
      template {
        data =  <<EOF
          proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;
          upstream frontend_upstream {
              server 127.0.0.1:${var.frontend_port};
          }
          server {
            server_name "";
            listen ${var.nginx_port};

            proxy_http_version 1.1;

            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            proxy_temp_file_write_size 64k;
            proxy_connect_timeout 10080s;
            proxy_send_timeout 10080;
            proxy_read_timeout 10080;
            proxy_buffer_size 64k;
            proxy_buffers 16 32k;
            proxy_busy_buffers_size 64k;
            proxy_redirect off;
            proxy_request_buffering off;
            proxy_buffering off;

            location / {
              proxy_pass http://frontend_upstream;
            }

            location /static {
              proxy_cache_valid 60m;
              proxy_pass http://frontend_upstream;
            }

            location /api {
              proxy_pass http://127.0.0.1:${var.public_api_port};
            }

            error_page   500 502 503 504  /50x.html;
            location = /50x.html {
              root   /usr/share/nginx/html;
            }
          }
        EOF
        destination = "local/nginx.conf"
      }
    }
  }
}