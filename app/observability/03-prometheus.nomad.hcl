job "prometheus" {
  type = "service"

  group "prometheus" {
    count = 1

    network {
      mode = "bridge"
      port "envoy_metrics" {
        to = 9102
      }       
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 300
      migrate = true
      sticky  = true
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: 'Consul Connect Metrics'
    metrics_path: "/metrics"
    consul_sd_configs:
    - server: "172.17.0.1:8500"
    relabel_configs:
      - source_labels: [__meta_consul_service]
        action: drop
        regex: (.+)-sidecar-proxy
      - source_labels: [__meta_consul_service_metadata_envoy_metrics_port]
        action: keep
        regex: (.+)
      - source_labels: [__address__, __meta_consul_service_metadata_envoy_metrics_port]
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
EOH
      }

      driver = "docker"
      config {
        image = "prom/prometheus:latest"
        args = [
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.path=/alloc/data",
          "--web.listen-address=0.0.0.0:9090",
          "--web.external-url=/",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles"
        ]        
        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]
      }
    }

    service {
      name = "prometheus-server"
      port = "9090"

      check {
        name     = "prometheus_ui port alive"
        expose   = true
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
        transparent_proxy {
        }
      }
    }
  }
}
