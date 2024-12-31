job "grafana" {
  group "grafana" {
    count = 1

    network {
      mode = "bridge"
      port "grafana" {
         to = "3000"
      }
    }

    service {
      name = "grafana"
      port = "grafana"
      meta {
        metrics_port = "${NOMAD_HOST_PORT_expose}"
      }

      check {
        type     = "http"
        name     = "grafana"
        path     = "/api/health"
        interval = "30s"
        timeout  = "10s"
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
  {{- range service "prometheus-server" }}
  url: http://{{ .Address }}:{{ .Port }}
  {{- end }}
  isDefault: true
  editable: false
EOF         
      perms = "777"
      }
    }
  }
}
