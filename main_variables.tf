# Ici est définie la région AWS (zone géographique) 
# Pour les besoins de l'exercice, "us-east-1" est utilisée, car c'est la
# seule autorisée sur mon lab. Dans la pratique "eu-west-3", qui correspond
# à la région Europe(Paris) pourrait être proposée pour satisfaire à des
# considérations de stockage de la donnée sur le sol européen et des besoins
# de performances au vu du positionnement géographique de la clientèle.
variable "dtt_region" {
  type        = string
  default     = "us-east-1"
  description = "Defines the AWS region used for the infrastructure"
}

# Tag d'environnement. Permet de tagger les machines pour classer les ressources
# selon leur environnement. Ex : Dev, Qual, Pré-production, Production...
variable "dtt_environment_tag" {
  description = "Defines the environment of the resource"
  default = "Production"
}

