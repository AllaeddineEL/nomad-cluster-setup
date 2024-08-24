job "vault-cluster" {
  namespace   = "vault-cluster"
  datacenters = ["dc1"]
  type        = "service"


  group "vault" {
    count = 3

    volume "vault_data" {
      type            = "csi"
      read_only       = false
      source          = "vault_volume"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      per_alloc       = true
    }

    network {

      mode = "host"

      port "api" {
        to     = "8200"
        static = "8200"
      }

      port "cluster" {
        to     = "8201"
        static = "8201"
      }
    }

    task "vault" {
      driver = "docker"

      volume_mount {
        volume      = "vault_data"
        destination = "${NOMAD_ALLOC_DIR}/vault/data"
        read_only   = false
      }

      config {
        image      = "hashicorp/vault:1.15"
        privileged = true

        ports = [
          "api",
          "cluster"
        ]

        volumes = [
          "local/config:/vault/config"
        ]

        command = "/bin/sh"
        args = [
          "-c",
          "vault operator init -status; if [ $? -eq 2 ]; then echo 'Vault is not initialized, starting in server mode...'; vault server -config=/vault/config; else echo 'Vault is already initialized, starting in server mode...'; vault server -config=/vault/config; fi"
        ]
      }

      template {
        data = <<EOH
ui = true

listener "tcp" {
  address         = "[::]:8200"
  cluster_address = "[::]:8201"
  tls_disable     = "true"
}

storage "raft" {
  path    = "${NOMAD_ALLOC_DIR}/vault/data"

{{- range nomadService "vault" }}
  retry_join {
    leader_api_addr = "http://{{ .Address }}:{{ .Port }}"
  }
  {{- end }}
}

cluster_addr = "http://{{ env "NOMAD_IP_cluster" }}:8201"
api_addr     = "http://{{ env "NOMAD_IP_api" }}:8200"

EOH

        destination = "local/config/config.hcl"
        change_mode = "noop"
      }

      service {
        name     = "vault"
        port     = "api"
        provider = "nomad"

        check {
          name     = "vault-api-health-check"
          type     = "http"
          path     = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 500
        memory = 1024

      }

      affinity {
        attribute = "${meta.node_id}"
        value     = "${NOMAD_ALLOC_ID}"
        weight    = 100
      }
    }
  }
}
