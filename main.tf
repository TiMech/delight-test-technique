# ------------------------------------------------------------------------------
# main.tf
# Ce document est le plan principal de la pile terraform, celui ou les
# ressources vont être déclarées. L'acronyme "dtt" utilisé dans la nomenclature
# signifie "delight technical test".
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# PROVIDERS
# Cette section décris les providers utilisés - des plugins utilisés pour gérer 
# les ressources.
# ------------------------------------------------------------------------------

terraform {
  required_providers {

    # Le test portant sur aws, on signifie à Terraform que l'on va utliser le
    # plug-in aws maintenu par Hashicorp (société propriétaire de Terraform)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuration du provider AWS.
provider "aws" {
  # Ici est définie la région AWS (zone géographique) ou sont rassemblés les 
  # services et serveurs qui vont être utilisés. Les régions AWS sont
  # indépendantes et seuls quelques services (S3 par exemple) sont tranverses.
  region = "${var.dtt_region}"
}

# ------------------------------------------------------------------------------
# VPC
# Dans cette section les virtual personnal cloud seront déclarés. Ce sont des
# réseaux virtuels au sein des régions AWS au sein desquels vont communiquer
# nos autres ressources de compute ou de stockage.
# ------------------------------------------------------------------------------

# Le VPC lui même. Il contiendra les sous-réseaux (subnets).
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "dtt_vpc" {

  # Le block CIDR indique l'IPV4 du réseau ainsi que la plage utlisable.
  cidr_block          = "${var.dtt_vpc_cidr_block}"

  # Selon si l'on souhaite faire tourner les instances EC2 associées sur des
  # tenants dédiés ou non.
  instance_tenancy    = "${var.dtt_vpc_instance_tenancy}"

  # Si l'on souhaite que le VPC supporte le DNS & que les hostnames puissent
  # être utilisés
  enable_dns_support   = var.dtt_vpc_dns_support
  enable_dns_hostnames = var.dtt_vpc_dns_hostnames

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-vpc",
    "environment"       = "${var.dtt_environment_tag}"
  }
}

# ------------------------------------------------------------------------------
# RDS
# Dans cette section sont déclarées les ressources utilisées pour la base de
# donnée relationelle
# ------------------------------------------------------------------------------

# On crée LES sous-réseaux utilisés pour acceuillir les ressources de la base
# de donnée sur plusieurs zones de disponibilité. Pour créer une ressource
# RDS, au moins deux sous-réseaux sur deux zones de disponibilités différentes
# sont nécessaires
resource "aws_subnet" "dtt_subnets_private_rds" {

  # Pour chaque clé de la variable on crée un sous-réseau
  for_each = var.dtt_rds_availability_zones_parameters

  # L'identifiant unique du VPC Hôte du sous réseau
  vpc_id                = aws_vpc.dtt_vpc.id

  # La plage sur laquelle le sous réseau s'étends
  cidr_block            = "${each.value.cidr_block}"

  # C'est un réseau privé donc le sous réseau ne doit pas se voir assigner une IP
  # publique
  map_public_ip_on_launch = false

  # Dans quelle zone de disponibilité de la région ce sous réseau doit-il
  # se trouver.
  availability_zone     = "${each.key}"

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-subnet-private-rds-${each.key}"
    environment         = "${var.dtt_environment_tag}"
    exposition          = "private"
  }
}

# Le groupe de sous-réseaux qui vont acceuillir la ressource de la base de
# donnée. On utilise les réseaux privés dédiés précédemment déclarés.
resource "aws_db_subnet_group" "dtt_subnet_group_rds" {
  name       = "dtt-subnet-group-rds"

  # Liste des sous-réseaux crée à partir des ressources précédemment initialisées
  subnet_ids = [for subnet in aws_subnet.dtt_subnets_private_rds : subnet.id]

  tags = {
    Name = "dtt-subnet-group-rds"
  }
}

resource "aws_db_instance" "dtt_rds" {

  # Type de d'instance acceuillant la BDD.
  # Consignes = "db.t4g.micro"
  instance_class         = "${var.dtt_rds_instance_type}"

  # Espace destockage alloué à la BDD
  allocated_storage      = var.dtt_rds_allocated_storage

  # Moteur de base de donné (MySQL, PostgreSQL, Aura...)
  # Consignes = "postgres"
  engine                 = "postgres"

  # Groupes de sécurité à appliquer sur la BDD. Ce sont les règles de filtrage
  # réseau qui vont être executées.
  vpc_security_group_ids = [aws_security_group.allow_bdd_in.id]

  # Nom d'utilisateur de l'administrateur
  username               = "${var.dtt_rds_username}"

  # Mot de passe de l'administrateur
  password               = "${var.dtt_rds_password}"

  # Est-ce que l'on souhaite eviter un snapshot lors de la supression de la BDD. 
  # Si non AWS effectuera un instantané de la base afin de pouvoir la restaurer 
  # au besoin. Dans les condition de l'exercice cela n'est pas nécessaire.
  skip_final_snapshot = true

  # Le groupe de sous-réseau à utiliser pour la ressource. Est utilisé le 
  # groupe précédemment déclaré.
  db_subnet_group_name   = aws_db_subnet_group.dtt_subnet_group_rds.name
}

# ------------------------------------------------------------------------------
# EC2
# Dans cette section sont déclarées les ressources utilisées pour les serveurs
# ------------------------------------------------------------------------------

# Le sous réseau public du VPC qui contiens la ressource de compute (instance EC2)
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "dtt_subnet_public_ec2" {

  # Pour chaque clé de la variable on crée un sous-réseau
  for_each = var.dtt_compute_availability_zones_parameters

  # L'identifiant unique du VPC Hôte du sous réseau
  vpc_id                = aws_vpc.dtt_vpc.id

  # La plage sur laquelle le sous réseau s'étends
  cidr_block            = "${each.value.cidr_block}"

  # C'est un réseau public donc le sous réseau doit se voir assigner une IP
  # publique
  map_public_ip_on_launch = true

  # Dans quelle zone de disponibilité de la région ce sous réseau doit-il
  # se trouver.
  availability_zone     = "${each.key}"

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-subnet-public-compute-${each.key}"
    environment         = "${var.dtt_environment_tag}"
    exposition          = "public"
  }
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# Dans cette section sont déclarées les groupes et règles de sécurité
# ------------------------------------------------------------------------------

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.dtt_vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22 
    to_port          = 22 
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_bdd_in" {
  vpc_id      = aws_vpc.dtt_vpc.id
  name        = "allow_bdd_in"
  description = "Allow all inbound traffic for Postgres"
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}