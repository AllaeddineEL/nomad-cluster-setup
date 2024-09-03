data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT
  license_path = "/etc/nomad.d/license.hclic"
  oidc_issuer      = "http://$IP_ADDRESS:4646"
}

consul {
  address = "127.0.0.1:8500"
  token = "CONSUL_TOKEN"
}

acl {
  enabled = true
}
vault {
  enabled = true
  default_identity {
    aud  = ["vault.io"]
    env  = false
    file = true
    ttl  = "1h"
  }
}