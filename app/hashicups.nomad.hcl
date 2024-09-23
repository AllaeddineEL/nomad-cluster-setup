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

variable "nginx_port" {
  description = "Nginx Port"
  default = 80
}
variable "nomad_ns" {
  description = "The Namespace name to deploy the DB task"
  default = "frontend-team"
}
# Begin Job Spec

job "nginx-reverse-proxy" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters
  namespace = var.nomad_ns
  group "nginx" {
    network {
      mode = "host"
      port "nginx" {
        static = var.nginx_port
        to = var.nginx_port
      }
    }
    task "nginx" {
      driver = "docker"
      service {
        name = "nginx"
        provider = "consul"
        port = "nginx"
     #   address  = attr.unique.platform.aws.public-hostname
      }
      meta {
        service = "nginx-reverse-proxy"
      }
      config {
        image = "hashicorpdemoapp/frontend-nginx:v1.0.9"
        ports = ["nginx"]
        network_mode = "host"
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      env {
          NEXT_PUBLIC_FOOTER_FLAG = "HashiCups-v1"
          NEXT_PUBLIC_PUBLIC_API_URL="/"
      }
      template {
        data =  <<EOF
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;
server {
  listen {{ env "NOMAD_PORT_nginx" }};
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
  location /api {
    {{ range service "public-api" }}
      proxy_pass http://{{ .Address }}:{{ .Port }};
    {{ end }}
  }
}
        EOF
        destination = "local/default.conf"
      }
    }
  }
}