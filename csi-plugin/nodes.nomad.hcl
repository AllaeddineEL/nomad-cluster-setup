job "csi-nodes" {
  namespace   = "nomad-system"
  datacenters = ["dc1"]
  type = "system"
  group "csi-nodes" {
    task "plugin" {
      driver = "docker"
      template {
        data = <<EOH
{{ with nomadVar "nomad/jobs/csi-nodes" }}{{ .service_account }}{{ end }}
EOH
  destination = "secrets/creds.json"
      }
      env {
        GOOGLE_APPLICATION_CREDENTIALS = "/secrets/creds.json"
      }
      config {
        image = "registry.k8s.io/cloud-provider-gcp/gcp-compute-persistent-disk-csi-driver:v1.13.2"
        args = [
          "--endpoint=unix:///csi/csi.sock",
          "--v=6",
          "--logtostderr",
          "--run-controller-service=false"
        ]
        privileged = true
      }
      csi_plugin {
        id        = "gcepd"
        type      = "node"
        mount_dir = "/csi"
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}