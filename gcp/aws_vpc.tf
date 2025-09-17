data "aws_availability_zones" "available" {
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name                   = "${local.cluster_id}-vpc"
  cidr                   = "10.0.0.0/16"
  azs                    = data.aws_availability_zones.available.names
  public_subnets         = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets        = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = false
}

resource "hcp_hvn" "main" {
  hvn_id         = local.hvn_id
  cloud_provider = "aws"
  region         = local.hvn_region
  cidr_block     = "172.25.32.0/20"
}

module "aws_hcp_consul" {
  source  = "hashicorp/hcp-consul/aws"
  version = "~> 0.7.0"

  hvn             = hcp_hvn.main
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  route_table_ids = module.vpc.public_route_table_ids
}

# resource "hcp_consul_cluster" "main" {
#   cluster_id      = local.cluster_id
#   hvn_id          = hcp_hvn.main.hvn_id
#   public_endpoint = true
#   tier            = "development"
# }
