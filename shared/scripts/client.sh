#!/bin/bash

set -ex

CONFIGDIR=/ops/shared/config

CONSULCONFIGDIR=/etc/consul.d
NOMADCONFIGDIR=/etc/nomad.d
CONSULTEMPLATECONFIGDIR=/etc/consul-template.d
HOME_DIR=ubuntu
NOMAD_DRIVER_EXEC2_VER=0.1.0

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`)
CLOUD=$1
RETRY_JOIN=$2


# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    IP_ADDRESS=$(curl http://instance-data/latest/meta-data/local-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

# Consul
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/consul_client.hcl
sudo cp $CONFIGDIR/consul_client.hcl $CONSULCONFIGDIR/consul.hcl

sudo systemctl enable consul.service

sudo cp $CONFIGDIR/nomad_client.hcl $NOMADCONFIGDIR/nomad.hcl

# Install the Nomad exec2 driver.

sudo mkdir -p /opt/nomad/data/plugins
sudo chmod 755 /opt/nomad/data/plugins
curl -OL https://releases.hashicorp.com/nomad-driver-exec2/${NOMAD_DRIVER_EXEC2_VER}/nomad-driver-exec2_${NOMAD_DRIVER_EXEC2_VER}_linux_amd64.zip
unzip nomad-driver-exec2_${NOMAD_DRIVER_EXEC2_VER}_linux_amd64.zip
chmod +x nomad-driver-exec2 && sudo mv nomad-driver-exec2 /opt/nomad/data/plugins/
rm LICENSE.txt nomad-driver-exec2_${NOMAD_DRIVER_EXEC2_VER}_linux_amd64.zip

# Install and link CNI Plugins to support Consul Connect-Enabled jobs

export ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.5.1
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}".tgz && \
sudo mkdir -p /opt/cni/bin && sudo mkdir -p /opt/cni/config && \
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz && sudo  ln -s /usr/lib/cni /opt/cni/bin
sudo cp $CONFIGDIR/cni.conflist /opt/cni/config/cni.conflist
sudo modprobe bridge
sudo modprobe br_netfilter

sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

sudo apt-get install -y consul-cni

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646

# Consul Template

sudo cp $CONFIGDIR/consul-template.hcl $CONSULTEMPLATECONFIGDIR/consul-template.hcl
sudo cp $CONFIGDIR/consul-template.service /etc/systemd/system/consul-template.service

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add systemd-resolved configuration for Consul DNS
# ref: https://developer.hashicorp.com/consul/tutorials/networking/dns-forwarding#systemd-resolved-setup
sed -i "s/DOCKER_BRIDGE_IP_ADDRESS/$DOCKER_BRIDGE_IP_ADDRESS/g" $CONFIGDIR/consul-systemd-resolved.conf
sudo mkdir -p /etc/systemd/resolved.conf.d/
sudo cp $CONFIGDIR/consul-systemd-resolved.conf /etc/systemd/resolved.conf.d/consul.conf
sudo systemctl restart systemd-resolved

# Set env vars for tool CLIs
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre"  | sudo tee --append /home/$HOME_DIR/.bashrc
