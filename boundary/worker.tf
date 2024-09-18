resource "random_uuid" "worker_uuid" {}

resource "boundary_worker" "hcp_pki_worker" {
  scope_id                    = "global"
  name                        = "boundary-worker-${random_uuid.worker_uuid.result}"
  worker_generated_auth_token = ""
}

locals {
  boundary_worker_config = <<-WORKER_CONFIG
    hcp_boundary_cluster_id = "${split(".", split("//", data.terraform_remote_state.boundary_demo_init.outputs.boundary_url)[1])[0]}"
    listener "tcp" {
      purpose = "proxy"
      address = "0.0.0.0"
    }
    worker {
      auth_storage_path = "/boundary/boundary-worker-${random_uuid.worker_uuid.result}"
      controller_generated_activation_token = "${boundary_worker.hcp_pki_worker.controller_generated_activation_token}"
      recording_storage_path="/boundary/storage/"
      tags {
        type = "public_instance"
        cloud = "gcp"
        region = "${var.region}"
      }
    }
    WORKER_CONFIG
}
resource "nomad_namespace" "boundary" {
  name        = "boundary"
  description = "Boundary worker namespace"
}

resource "nomad_job" "boundary_worker" {
  purge_on_destroy = true
  jobspec          = <<EOT
job "boundary-worker" {
  namespace   = "${nomad_namespace.boundary.name}" 
  type        = "service"
  region      = "global"
  datacenters = ["dc1"]

  group "worker" {
    count = 1
    service {
      name     = "boundary-worker"
      tags     = ["worker"]
      provider = "consul"
      port     = "worker"
    }
    network {
      port "worker" {
        static = 9202
      }
    }

    task "worker" {
      driver = "raw_exec"

      config {
        command = "/tmp/boundary"
        args = ["server", "-config=tmp/config.hcl"]
        ports = [
          "worker"
        ]
      }

      artifact {
        source      = "https://releases.hashicorp.com/boundary/${var.boundary_version}+ent/boundary_${var.boundary_version}+ent_linux_amd64.zip"
        destination = "./tmp/"
      }

      template {
        data        = ${local.boundary_worker_config}
        destination = "tmp/config.hcl"
      }

      env {
        SKIP_SETCAP = true
      }

      resources {
        memory = 600
      }
    }
  }
}  
EOT
}
