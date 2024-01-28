
# ------------------------------------------------------------------------------
# RESOURCES - VPC
# Dans cette section les virtual personnal cloud seront déclarés. Ce sont des
# réseaux virtuels au sein des régions AWS au sein desquels vont communiquer
# nos autres ressources de compute ou de stockage.
# ------------------------------------------------------------------------------

# Le VPC lui même. Il contiendra les sous-réseaux (subnets).
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "dtt_vpc" {

  # Le block CIDR indique l'IPV4 du réseau ainsi que la plage utlisable.
  cidr_block          = var.dtt_vpc_cidr_block

  # Selon si l'on souhaite faire tourner les instances EC2 associées sur des
  # tenants dédiés ou non.
  instance_tenancy    = var.dtt_vpc_instance_tenancy

  # Si l'on souhaite que le VPC supporte le DNS & que les hostnames puissent
  # être utilisés
  enable_dns_support   = var.dtt_vpc_dns_support
  enable_dns_hostnames = var.dtt_vpc_dns_hostnames

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "vpc_delight_technical_test",
    "environment"       = var.dtt_environment_tag
  }
}