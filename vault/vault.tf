resource "nomad_job" "vault" {
  #jobspec          = file("vault.nomad.hcl")

  purge_on_destroy = true
  jobspec          = <<EOT

job "vault-cluster" {
  namespace   = "vault-cluster"
  datacenters = ["dc1"]
  type        = "service"


  group "vault" {
    count = 3

    volume "vault_data" {
      type            = "csi"
      read_only       = false
      source          = "vault-volume"
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
  path    = "{{ env "NOMAD_ALLOC_DIR" }}/vault/data"

{{- range nomadService "vault" }}
  retry_join {
    leader_api_addr = "http://{{ .Address }}:{{ .Port }}"
  }
  {{- end }}
}

cluster_addr = "http://{{ env "NOMAD_IP_cluster" }}:8201"
api_addr     = "http://{{ env "NOMAD_IP_api" }}:8200"

seal "gcpckms" {
  project     = "${data.terraform_remote_state.local.outputs.project}"
  region      = "${data.terraform_remote_state.local.outputs.keyring_location}"
  key_ring    = "${data.terraform_remote_state.local.outputs.key_ring}"
  crypto_key  = "${data.terraform_remote_state.local.outputs.crypto_key}"
}
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
  EOT

  depends_on = [
    nomad_namespace.vault,
    nomad_csi_volume.vault_volume
  ]
}

resource "terracurl_request" "init" {
  method         = "POST"
  name           = "init"
  response_codes = [200]
  url            = "http://${data.terraform_remote_state.local.outputs.clients_lb}:8200/v1/sys/init"

  request_body   = <<EOF
{
  "secret_shares": 3,
  "secret_threshold": 2
}
EOF
  max_retry      = 7
  retry_interval = 10

  depends_on = [
    nomad_job.vault
  ]
}

output "init" {
  value = terracurl_request.init.response
}

resource "nomad_variable" "unseal" {
  path      = "nomad/jobs/vault-unsealer"
  namespace = "vault-cluster"

  items = {
    key1 = jsondecode(terracurl_request.init.response).keys[0]
    key2 = jsondecode(terracurl_request.init.response).keys[1]
    key3 = jsondecode(terracurl_request.init.response).keys[2]
  }
}

resource "nomad_job" "vault-unsealer" {
  jobspec = file("vault-unsealer.nomad")
  depends_on = [
    nomad_namespace.vault,
    nomad_variable.unseal,
    nomad_job.vault
  ]
}
