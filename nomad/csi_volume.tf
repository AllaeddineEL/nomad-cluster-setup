resource "nomad_namespace" "vault" {
  name        = "vault-cluster"
  description = "Vault servers namespace"
}

data "nomad_plugin" "gcepd" {
  plugin_id        = "gcepd"
  wait_for_healthy = true
}

resource "nomad_csi_volume" "mysql_volume" {
  depends_on = [data.nomad_plugin.gcepd]
  namespace  = nomad_namespace.vault.name
  lifecycle {
    prevent_destroy = true
  }

  plugin_id    = data.nomad_plugin.gcepd.plugin_id
  volume_id    = "vault_volume"
  name         = "vault_volume"
  capacity_min = "10GB"
  capacity_max = "20GB"

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }

  mount_options {
    fs_type = "ext4"
  }

  topology_request {
    required {
      topology {
        segments = {
          region = var.region
          zone   = var.zone
        }
      }
    }
  }
}
