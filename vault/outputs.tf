output "vault_url" {
  value = "http://${data.terraform_remote_state.local.outputs.clients_lb}:8200"
}
