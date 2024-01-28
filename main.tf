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
  region = var.dtt_region
}

