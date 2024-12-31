job "grafana" {
  group "grafana" {
    count = 1

    network {
      mode = "bridge"
      port "expose" {}
    }

    service {
      name = "grafana"
      port = "3000"
      meta {
        metrics_port = "${NOMAD_HOST_PORT_expose}"
      }

      check {
        expose   = true
        type     = "http"
        name     = "grafana"
        path     = "/api/health"
        interval = "30s"
        timeout  = "10s"
      }

      connect {
        sidecar_service {
          proxy {
            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 9102
                listener_port   = "expose"
              }
            }
            transparent_proxy {
            }
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9102"
            }
          }
        }
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"

        volumes = [
          "local/provisioning/prom.yml:/etc/grafana/provisioning/datasources/prometheus.yml"
        ]
      }



      env {
        GF_PATHS_CONFIG = "/local/config.ini"
        GF_PATHS_PROVISIONING = "/local/provisioning"
      }

      template {
        destination = "local/config.ini"
        data        = <<EOF
[database]
type = sqlite3
[server]
serve_from_sub_path = true
root_url = "/grafana"
EOF
      }

      template {
        destination = "local/provisioning/datasources/prom.yml"
        data        = <<EOF
apiVersion: 1

datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://prometheus-server.virtual.global:9090
  isDefault: true
  editable: false
EOF         
      perms = "777"
      }
    }
  }
}
