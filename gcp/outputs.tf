output "lb_address_consul_nomad" {
  value = "http://${google_compute_forwarding_rule.servers_default.ip_address}"
}

output "consul_bootstrap_token_secret" {
  value = random_uuid.consul_token[1].result
}


output "IP_Addresses" {
  value = <<CONFIGURATION

The Consul UI can be accessed at http://${google_compute_forwarding_rule.servers_default.ip_address}:8500/ui
with the bootstrap token: ${random_uuid.consul_token[1].result}
The Nomad UI can be accessed at http://${google_compute_forwarding_rule.servers_default.ip_address}:4646/ui

CONFIGURATION
}


output "clients_lb" {
  value = google_compute_forwarding_rule.clients_default.ip_address
}

output "gcp_project" {
  value = var.project
}
output "keyring_location" {
  value = google_kms_key_ring.key_ring.location
}
output "key_ring" {
  value = google_kms_key_ring.key_ring.name
}
output "crypto_key" {
  value = google_kms_crypto_key.crypto_key.name
}
output "kms_sa_key" {
  sensitive = true
  value     = google_service_account_key.vault_kms_service_account_key.private_key
}
