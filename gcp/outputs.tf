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


#with the bootstrap token: ${data.consul_keys.nomad_token.var.nomad_mgmt_token}
