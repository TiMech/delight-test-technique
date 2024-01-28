# Le block CIDR indique l'IPV4 du réseau ainsi que la plage utlisable.
# La valeur initialement proposée par AWS permet 65 536 IPs, nous conserverons
# cette valeur. 
# - Format : Notation CIDR - XXX.XXX.XXX.XXX/YY où XXX est entre 0 et 255 et YY
# entre 1 et 32
# - Ex: "10.0.0.0/16"
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#cidr_block
variable "dtt_vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Defines the CIDR block used for the VPC declaration"
}

# Ce paramètre est à modifier si l'on souhaite faire tourner les instances
# EC2 associées à ce VPC sur des tenants dédiés. Nous souhaitons conserver
# la valeur par défaut.
# Valeurs : "default" | "dedicated"
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#instance_tenancy
variable "dtt_vpc_instance_tenancy" {
  type        = string
  default     = "default"
  description = "Defines the tenancy of EC2 instances used for the VPC declaration"
}

# Ce paramètre indique si l'on souhaite que notre VPC supporte le DNS.
# Valeurs : true | false
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#enable_dns_support
variable "dtt_vpc_dns_support" {
  type        = bool
  default     = true
  description = "Defines if we want the VPC to support DNS"
}

# Ce paramètre indique si l'on souhaite que notre VPC supporte les noms d'hôtes.
# Valeurs : true | false
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#enable_dns_hostnames
variable "dtt_vpc_dns_hostnames" {
  type        = bool
  default     = true
  description = "Defines if we want the VPC to support DNS hostnames"
}