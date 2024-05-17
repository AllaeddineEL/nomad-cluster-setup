# Packer variables (all are required)
project                   = "GCP_PROJECT_ID"
region                    = "europe-west1"
zone                      = "europe-west1-b"

# Terraform variables (all are required)
retry_join                = "project_name=GCP_PROJECT_ID zone_pattern=europe-west1-b provider=gce tag_value=auto-join"

# These variables will default to the values shown
# and do not need to be updated unless you want to
# change them
# allowlist_ip            = "0.0.0.0/0"
# name                    = "nomad"
# server_instance_type    = "t2.micro"
# server_count            = "3"
# client_instance_type    = "t2.micro"
# client_count            = "3"