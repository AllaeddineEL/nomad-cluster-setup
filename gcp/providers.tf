terraform {
  required_version = ">= 0.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.21.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.1"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.18.0"
    }
  }
}
resource "random_string" "tutorial" {
  length  = 4
  special = false
  upper   = false
}



provider "aws" {
  region = var.aws_region
}
provider "google" {
  project = var.project
  region  = var.gcp_region
  zone    = var.zone
}

provider "consul" {
  datacenter = var.datacenter
  address    = "${google_compute_forwarding_rule.servers_default.ip_address}:8443"
  token      = random_uuid.consul_mgmt_token.result
  ca_pem     = tls_self_signed_cert.datacenter_ca.cert_pem
  scheme     = "https"
}

provider "nomad" {
  address     = "https://${google_compute_forwarding_rule.servers_default.ip_address}:4646"
  region      = var.domain
  secret_id   = random_uuid.nomad_mgmt_token.result
  ca_pem      = tls_self_signed_cert.datacenter_ca.cert_pem
  skip_verify = true
  ignore_env_vars = {
    "NOMAD_ADDR" : true,
    "NOMAD_TOKEN" : true,
    "NOMAD_CACERT" : true,
    "NOMAD_TLS_SERVER_NAME" : true,
  }
}
