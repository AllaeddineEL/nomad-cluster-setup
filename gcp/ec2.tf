data "aws_ami" "hashistack" {
  most_recent = true
  name_regex  = "^hashistack.*"


  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["self"]
}

// Key pair
resource "aws_key_pair" "consul_client" {
  key_name   = "consul-client"
  public_key = trimspace(tls_private_key.ssh_key.public_key_openssh)
}

// Security groups
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.default_vpc_id

  ingress {
    description      = "SSH into instance"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "allow_ssh"
  }
}

// Consul client instance
resource "aws_instance" "consul_client" {
  count                       = var.aws_client_count
  ami                         = data.aws_ami.hashistack.id
  instance_type               = "t2.small"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id
  ]
  key_name = aws_key_pair.consul_client.key_name

  user_data = templatefile("${path.module}/../shared/data-scripts/user-data-client.sh", {
    region     = var.aws_region
    cloud_env  = "aws"
    retry_join = google_compute_forwarding_rule.servers_default.ip_address

    domain           = var.domain,
    datacenter       = var.datacenter,
    consul_node_name = "consul-aws-client-${count.index}",

    consul_encryption_key = random_id.consul_gossip_key.b64_std,
    consul_agent_token    = "${data.consul_acl_token_secret_id.consul-client-agent-token[count.index].secret_id}",
    consul_default_token  = "${data.consul_acl_token_secret_id.consul-client-default-token[count.index].secret_id}",
    nomad_node_name       = "nomad-aws-client-${count.index}",
    nomad_agent_meta      = "isPublic = false"
    nomad_agent_token     = "${data.consul_acl_token_secret_id.nomad-client-consul-token[count.index].secret_id}",
    ca_certificate        = base64gzip("${tls_self_signed_cert.datacenter_ca.cert_pem}"),
    agent_certificate     = base64gzip("${tls_locally_signed_cert.client_cert[count.index].cert_pem}"),
    agent_key             = base64gzip("${tls_private_key.client_key[count.index].private_key_pem}")
  })

  tags = {
    Name = "consul-client-${count.index}"
  }
}
