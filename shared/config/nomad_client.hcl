data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "dc1"

# Enable the client
client {
  enabled = true
  cni_path = "opt/cni/bin"
  cni_config_dir = "opt/cni/config"
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}

acl {
  enabled = true
}

consul {
  address = "127.0.0.1:8500"
  token = "CONSUL_TOKEN"
}

vault {
  enabled = true
  address = "http://vault.service.consul:8200"
   default_identity {
    aud = ["vault.io"]
    ttl = "1h"
  }
}