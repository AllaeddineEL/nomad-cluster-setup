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

# Begin Job Spec

job "hashicups-nginx" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters

  group "nginx" {
    network {
      port "nginx" {
        static = var.nginx_port
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
        image = "nginx:alpine"
        ports = ["nginx"]
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      template {
        data =  <<EOF
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;
upstream frontend_upstream {
  {{ range service "frontend" }}
    server {{ .Address }}:{{ .Port }};{{- end }}
}
server {
  listen {{ env "NOMAD_PORT_nginx" }};
  server_name {{ env "NOMAD_IP_nginx" }};
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
  location /_next/static {
    proxy_cache STATIC;
    proxy_pass http://frontend_upstream;
    # For testing cache - remove before deploying to production
    add_header X-Cache-Status $upstream_cache_status;
  }
  location /static {
    proxy_cache STATIC;
    proxy_ignore_headers Cache-Control;
    proxy_cache_valid 60m;
    proxy_pass http://frontend_upstream;
    # For testing cache - remove before deploying to production
    add_header X-Cache-Status $upstream_cache_status;
  }
  location / {
    proxy_pass http://frontend_upstream;
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