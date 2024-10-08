terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.3.1"
    }

    terracurl = {
      source  = "devops-rob/terracurl"
      version = "1.2.1"
    }
  }
}

data "terraform_remote_state" "local" {
  backend = "local"

  config = {
    path = "${path.module}/../gcp/terraform.tfstate"
  }

}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "terracurl" {}


provider "consul" {
  address = "${data.terraform_remote_state.local.outputs.lb_address_consul_nomad}:8500"
  token   = data.terraform_remote_state.local.outputs.consul_bootstrap_token_secret
}

data "consul_keys" "nomad_token" {
  key {
    name = "nomad_mgmt_token"
    path = "nomad_mgmt_token"
  }
}

provider "nomad" {
  address   = "${data.terraform_remote_state.local.outputs.lb_address_consul_nomad}:4646"
  secret_id = data.consul_keys.nomad_token.var.nomad_mgmt_token
}
