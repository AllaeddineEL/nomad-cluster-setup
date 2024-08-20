output "lb_address_consul_nomad" {
  value = "http://${google_compute_forwarding_rule.servers_default.ip_address}"
}

output "consul_bootstrap_token_secret" {
  value = random_uuid.consul_token[1].result
}

output "IP_Addresses" {
  value = <<CONFIGURATION

Client public IPs: ${join(", ", google_compute_instance.client[*].network_interface.0.network_ip)}

Server public IPs: ${join(", ", google_compute_instance.server[*].network_interface.0.network_ip)}

The Consul UI can be accessed at http://${google_compute_forwarding_rule.servers_default.ip_address}:8500/ui
with the bootstrap token: ${random_uuid.consul_token[1].result}
CONFIGURATION
}
