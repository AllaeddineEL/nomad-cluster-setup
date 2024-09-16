resource "nomad_job" "vault" {
  #jobspec          = file("vault.nomad.hcl")

  purge_on_destroy = true
  jobspec          = <<EOT
job "boundary-worker-raw" {
  type        = "service"
  region = "global"
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
      }

      artifact {
        source      = "https://releases.hashicorp.com/boundary/${var.boundary_version}+ent/boundary_${var.boundary_version}+ent_linux_arm64.zip"
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
