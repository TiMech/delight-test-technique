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

# Table de routage qui sera utilisé dans le sous-réseau privé de la BDD
# Le sujet ne précise pas de règles de sortie depuis le sous-réseau donc
# aucune n'est ajoutée. En conséquence, aucun traffic sortant ne sera 
# routé en dehors du VPC.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "dtt_route_private_rds" {

  # Le vpc qui acceuillera la table de routage
  vpc_id = aws_vpc.dtt_vpc.id

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-route-private-rds"
    environment         = "${var.dtt_environment_tag}"
    exposition          = "private"
  }  
}

# Associe la table de routage privée RDS avec les sous-réseaux cible.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "dtt_subnet_route_association_private_rds" {

  # On itère sur chaque sous-réseau privé utlisé pour acceuillir la base de
  # donnée.
  for_each       = aws_subnet.dtt_subnets_private_rds

  # L'identifiant du sous réseau à associer : le sous-réseau public compute
  subnet_id      = each.value.id

  # L'identifiant de la table de routage à associer
  route_table_id = aws_route_table.dtt_route_private_rds.id
}

# Crée une instance de base de donnée relationnelle de type PostgreSQL selon
# le format défini dans le sujet. On y ajoute une database de test afin
# de pouvoir évaluer la connection.
resource "aws_db_instance" "dtt_rds" {

  # Type de d'instance acceuillant la BDD.
  # Consignes = "db.t4g.micro"
  instance_class         = "${var.dtt_rds_instance_type}"

  # Espace destockage alloué à la BDD
  allocated_storage      = var.dtt_rds_allocated_storage

  # Nom de la base de donnée initiale (utilisé pour créer une base à observer
  # dans le cadre du test)
  db_name               = "mydb"

  # Moteur de base de donné (MySQL, PostgreSQL, Aura...)
  # Consignes = "postgres"
  engine                 = "postgres"

  # Groupes de sécurité à appliquer sur la BDD. Ce sont les règles de filtrage
  # réseau qui vont être executées.
  vpc_security_group_ids = [aws_security_group.dtt_allow_bdd_in.id]

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
resource "aws_subnet" "dtt_subnets_public_ec2" {

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


# Table de routage qui sera utilisé dans le sous-réseau public des EC2.*
# Le sujet ne précise pas de règles de sortie depuis le sous-réseau donc
# aucune n'est ajoutée. En conséquence, aucun traffic sortant ne sera 
# routé en dehors du VPC.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "dtt_route_public_ec2" {

  # Le vpc qui acceuillera la table de routage
  vpc_id = aws_vpc.dtt_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dtt-internet-gw.id
  }

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-route-public-compute"
    environment         = "${var.dtt_environment_tag}"
    exposition          = "public"
  }  
}

# Associe la table de routage publique EC2 avec le sous-réseau cible.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "dtt_subnet_route_association_public_ec2" {

  # On itère sur chaque sous-réseau privé utlisé pour acceuillir la base de
  # donnée.
  for_each       = aws_subnet.dtt_subnets_public_ec2

  # L'identifiant du sous réseau à associer : le sous-réseau public compute
  subnet_id      = each.value.id

  # L'identifiant de la table de routage à associer
  route_table_id = aws_route_table.dtt_route_public_ec2.id
}

resource "aws_key_pair" "dtt_key_compute" {
  key_name    = "dtt-key-compute"
  public_key  = file("dtt_compute_key.pub")  
}

# Instances EC2 de calcul, le "serveur" de l'exercice.Une seule machine est
# configurée dans les paramètres donc une seule instance sera initiée. 
resource "aws_instance" "dtt_compute_instances" {

  # On itère sur chaque instance définie dans les paramètres (1 pour l'exemple)
  for_each       = var.dtt_compute_instances_parameters

  # Image machine à utiliser
  ami           = data.aws_ami.dtt_ami_al2023.id

  # Format d'instance à utiliser
  instance_type = "${each.value.type}"

  # L'identifiant du sous réseau public à associer à l'instance, on récupère celui
  # associé à la zone de disponibilité.
  subnet_id     = aws_subnet.dtt_subnets_public_ec2[each.value.availability_zone].id

  # On ajoute les règles de filtrage permettant l'accès SSH
  vpc_security_group_ids = [aws_security_group.dtt_allow_ssh_in.id, aws_security_group.dtt_allow_traffic_out.id]

  # La clé ssh à utiliser pour se connecter à l'instance
  key_name      = aws_key_pair.dtt_key_compute.key_name

  tags = {
    Name = "dtt-compute-instance"
  }
}

# Passerelle permettant à l'instace EC2 de communiquer avec avec internet. Utile
# pour récupérer le client Postgresql afin de communiquer avec le serveur de BDD
resource "aws_internet_gateway" "dtt-internet-gw" {
  vpc_id = aws_vpc.dtt_vpc.id

  tags = {
    Name = "main"
  }
}

# Ressource elastic IP permettant à l'instance EC2 de posséder une IP publique
# afin de pouvoir se connecter directement sur la machine depuis internet
resource "aws_eip" "dtt_compute_eip" {

  # On itère sur chaque sous-réseau public utlisé
  for_each = aws_instance.dtt_compute_instances
  instance = each.value.id
  depends_on = [aws_internet_gateway.dtt-internet-gw]
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# Dans cette section sont déclarées les groupes et règles de sécurité
# ------------------------------------------------------------------------------

# Règle de filtrage permettant le passage des paquets sur le port 22 entrant
# afin d'autoriser les connection SSH entrante.
resource "aws_security_group" "dtt_allow_ssh_in" {

  # Nom de la règle
  name        = "dtt-allow-ssh-in"

  # VPC acceuillant la règle 
  vpc_id      = aws_vpc.dtt_vpc.id

  # Flux entrant avec ses caractéristiques (ports, protocole concerné, plage
  # d'adresses concernées par la règle...). Ici on autorise la connection depuis
  # n'importe quelle adresse IP
  ingress {
    description      = "SSH from VPC"
    from_port        = 22 
    to_port          = 22 
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-allow-ssh-in"
    environment         = "${var.dtt_environment_tag}"
  }
}

# Règle de filtrage permettant la communication sortante vers le port 5432 
# utilisé par la BDD. 
resource "aws_security_group" "dtt_allow_traffic_out" {

  # Nom de la règle
  name        = "dtt-allow-traffic-out"

  # VPC acceuillant la règle 
  vpc_id      = aws_vpc.dtt_vpc.id

  # Permet les flux sortants de la machine (A restreindre selon les besoins
  # effectifs)
  egress {
    description      = "Allow outgoing traffic"
    from_port        = 0 
    to_port          = 0 
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-allow-traffic-out"
    environment         = "${var.dtt_environment_tag}"
  }
}

# Règle de filtrage permettant la communication sortante vers le port 5432 
# utilisé par la BDD. 
resource "aws_security_group" "dtt_allow_bdd_in" {

  # Nom de la règle
  name        = "dtt-allow-bdd-in"

  # VPC acceuillant la règle 
  vpc_id      = aws_vpc.dtt_vpc.id

  # Flux entrant avec ses caractéristiques (ports, protocole concerné, plage
  # d'adresses concernées par la règle...). Ici on autorise la sortie vers
  # n'importe quelle IP vers le port 5432
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Les étiquettes utilisées pour classer les ressources ou indentifier des
  # groupes de ressources définies
  tags = {
    Name                = "dtt-allow-bdd-in"
    environment         = "${var.dtt_environment_tag}"
  }
}