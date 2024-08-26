provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "hashistack" {
  name = "hashistack-${var.name}"
}

resource "google_compute_firewall" "consul_nomad_ui_ingress" {
  name          = "${var.name}-ui-ingress"
  network       = google_compute_network.hashistack.name
  source_ranges = [var.allowlist_ip]

  # Nomad
  allow {
    protocol = "tcp"
    ports    = [4646]
  }

  # Consul
  allow {
    protocol = "tcp"
    ports    = [8500]
  }
  # Vault
  allow {
    protocol = "tcp"
    ports    = [8200]
  }
}

resource "google_compute_firewall" "ssh_ingress" {
  name          = "${var.name}-ssh-ingress"
  network       = google_compute_network.hashistack.name
  source_ranges = [var.allowlist_ip]

  # SSH
  allow {
    protocol = "tcp"
    ports    = [22]
  }
}

resource "google_compute_firewall" "allow_all_internal" {
  name        = "${var.name}-allow-all-internal"
  network     = google_compute_network.hashistack.name
  source_tags = ["auto-join"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

resource "google_compute_firewall" "clients_ingress" {
  name          = "${var.name}-clients-ingress"
  network       = google_compute_network.hashistack.name
  source_ranges = [var.allowlist_ip]
  target_tags   = ["nomad-clients"]

  # Add application ingress rules here
  # These rules are applied only to the client nodes

  # nginx example; replace with your application port
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8200"]
  }
}

data "google_compute_image" "hashistack_image" {

  most_recent = true
  filter      = "name eq ^hashistack.*"

}
resource "random_uuid" "consul_token" {
  count = 2
}

resource "google_compute_instance" "server" {
  count        = var.server_count
  name         = "${var.name}-server-${count.index}"
  machine_type = var.server_instance_type
  zone         = var.zone
  tags         = ["auto-join"]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.hashistack_image.self_link
      size  = var.root_block_device_size
    }
  }

  network_interface {
    network = google_compute_network.hashistack.name
    # access_config {
    #   // Leave empty to get an ephemeral public IP
    # }
  }

  service_account {
    # https://developers.google.com/identity/protocols/googlescopes
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }

  metadata_startup_script = templatefile("${path.module}/../shared/data-scripts/user-data-server.sh", {
    server_count              = var.server_count
    region                    = var.region
    cloud_env                 = "gce"
    retry_join                = var.retry_join
    nomad_binary              = var.nomad_binary
    nomad_consul_token_id     = random_uuid.consul_token[0].result
    nomad_consul_token_secret = random_uuid.consul_token[1].result
    nomad_license             = file("/root/license/license.nomad")
    consul_license            = file("/root/license/license.consul")
  })
  metadata = {
    "ssh-keys" = <<EOT
      ubuntu:${trimspace(tls_private_key.ssh_key.public_key_openssh)}
     EOT
  }

  # connection {
  #   type        = "ssh"
  #   user        = "ubuntu"
  #   private_key = tls_private_key.ssh_key.private_key_openssh
  #   agent       = "false"
  #   host        = self.network_interface.0.access_config.0.nat_ip
  # }
  # provisioner "file" {
  #   source      = "/root/license"
  #   destination = "/tmp"
  # }
  # provisioner "remote-exec" {

  #   inline = [
  #     "sudo mv /tmp/license/license.nomad /etc/nomad.d/license.hclic",
  #     "sudo mv /tmp/license/license.vault /etc/vault.d/license.hclic",
  #     "sudo mv /tmp/license/license.consul /etc/consul.d/license.hclic",
  #   ]
  # }

}

resource "google_compute_instance" "client" {
  count        = var.client_count
  name         = "${var.name}-client-${count.index}"
  machine_type = var.client_instance_type
  zone         = var.zone
  tags         = ["auto-join", "nomad-clients"]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.hashistack_image.self_link
      size  = var.root_block_device_size
    }
  }

  network_interface {
    network = google_compute_network.hashistack.name
    # access_config {
    #   // Leave empty to get an ephemeral public IP
    # }
  }

  service_account {
    # https://developers.google.com/identity/protocols/googlescopes
    scopes = [
      "logging-write",
      "cloud-platform",
      "compute-rw",
      "userinfo-email",
      "storage-ro"
    ]
  }

  metadata_startup_script = templatefile("${path.module}/../shared/data-scripts/user-data-client.sh", {
    region                    = var.region
    cloud_env                 = "gce"
    retry_join                = var.retry_join
    nomad_binary              = var.nomad_binary
    nomad_consul_token_secret = random_uuid.consul_token.1.result
  })
}
resource "google_compute_forwarding_rule" "servers_default" {
  project               = var.project
  name                  = var.name
  target                = google_compute_target_pool.servers.self_link
  load_balancing_scheme = "EXTERNAL"
}
resource "google_compute_target_pool" "servers" {
  name = "servers-pool"

  instances = google_compute_instance.server.*.self_link

}

resource "google_compute_forwarding_rule" "clients_default" {
  project               = var.project
  name                  = "clients-${var.name}"
  target                = google_compute_target_pool.client.self_link
  load_balancing_scheme = "EXTERNAL"
}
resource "google_compute_target_pool" "client" {
  name = "client-pool"

  instances = google_compute_instance.client.*.self_link

}
resource "google_compute_router" "router" {
  name    = "hashistack-${var.name}"
  region  = var.region
  network = google_compute_network.hashistack.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "hashistack-${var.name}"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
