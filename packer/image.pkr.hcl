packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

variable "gcp_project" {
  type = string
}

variable "gcp_zone" {
  type = string
}

source "googlecompute" "ubuntu" {
  image_name   = "hashistack-${local.timestamp}"
  project_id   = var.gcp_project
  source_image = "ubuntu-minimal-2404-noble-amd64-v20241004"
  ssh_username = "packer"
  zone         = var.gcp_zone
}
source "amazon-ebs" "ubuntu" {
  ami_name      = "hashistack-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "eu-central-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-minimal-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  tags = {
    Name = "{{ .SourceAMIName }}"
  }
}
build {
  sources = ["source.googlecompute.ubuntu",
  "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = ["sudo mkdir -p /ops/shared", "sudo chmod 777 -R /ops"]
  }

  provisioner "file" {
    destination = "/ops"
    source      = "../shared"
  }

  provisioner "shell" {
    only = ["googlecompute.ubuntu"]
    environment_vars = ["INSTALL_NVIDIA_DOCKER=false", "CLOUD_ENV=gce"]
    script           = "../shared/scripts/setup.sh"
  }
  provisioner "shell" {
    only = ["amazon-ebs.ubuntu"]
    environment_vars = ["INSTALL_NVIDIA_DOCKER=false", "CLOUD_ENV=aws"]
    script           = "../shared/scripts/setup.sh"
  }
}