resource "random_pet" "pet_name" {
}

resource "random_pet" "random_password" {
  length = 2
}

#Create New HCP Project for these resources
resource "hcp_project" "project" {
  name        = "instruqt-${random_pet.pet_name.id}"
  description = "Project Created by Instruqt Boundary Demo Lab"
}

#Create HCP Boundary Cluster
resource "hcp_boundary_cluster" "boundary-demo" {
  project_id = hcp_project.project.resource_id
  cluster_id = "instruqt-${random_pet.pet_name.id}"
  username   = "admin"
  password   = random_pet.random_password.id
  tier       = "PLUS"
}

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
