# Test Technique - Création d’une pile Terraform.

_ANDREY Thomas_
_Janvier 2024_

## Sujet

```
💡 Bien qu’utilisant des ressources AWS, ce test se base sur l’offre gratuite d’AWS. Il suffit juste de créer un nouveau compte pour en bénéficier.  **Cela ne doit rien couter!**

**Ne pas oublier de supprimer toutes vos instances après le test.**
```

Le but de ce test de faire un PoC qui permet de tester le déploiement d’une infrastructure simple à partir d’une pile Terraform. Si ce PoC est concluant, l’idée serait de généraliser l’approche à toute l’infrastructure de Delight, ce qui permettrait d’initialiser une approche IaC.

**Etapes du test**

1) Créer un compte AWS
2) Créer une pile terraform incluant une EC2 (t4g.micro) et une base de données RDS Postgresql (db.t4g.micro). S’assurer que le serveur puisse communiquer avec la base de données RDS.
3) Déployer cette pile sur le compte AWS
4) Mettre à disposition cette pile dans un répertoire Github. Ce répertoire devra contenir la pile et un README expliquant la procédure à suivre pour déployer la pile ainsi que la procédure qui a été suivie pour créer la pile.
5) Supprimer la EC2 et RDS.
6) Nous transmettre le répertoire en mode public.

## Déploiement de la pile Terraform

### Pré-requis

**AWS**
Avant toute chose, vous devez disposer d'un compte AWS et des credentials pour y accéder et créer des ressources.
Assurer-vous que vos credentials soient présents dans le fichier `~/.aws/credentials`. Terraform utilisera ces éléments pour se connecter.

**Terraform**
Terraform doit être installé sur votre poste de travail. Veuillez vous référer au lien suivant pour connaitre la démarche à adopter suivant votre configuration : https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

Il faut maintenant télécharger les plugins nécessaires à l'execution de notre plan terraform. Pour cela, ouvrez un terminal de commande et placez vous dans le dossier où sont situés les fichiers du plan terraform. Entrez la commande ci-dessous pour lancer le téléchargement des plugins.

```sh
$ terraform init
```

Un message de succès devrait apparaitre après le téléchargement.

```sh
Terraform has been successfully initialized!
```

**Il n'est pas nécessaire de réitérer cette étape a chaque application du plan, seulement si un nouveau plugin doit être téléchargé.**

### Vérification et déploiement

L'ensemble des étapes suivantes vont tous se dérouler dans la même console, afin de conserver en mémoire les variables d'environnement.

**Renseigner les secrets**

**Ce procédé est utilisé tel quel pour les besoins de simplicité de l'exercice et ne relève aucunement d'une "best practice" qui nécessiterait de récupérer les secrets depuis des stockages sécurisés (Ex: AWS Secret Manager).**

Nous allons entrer les secrets en tant que variable d'environnement pour qu'ils soient utilisés par le plan Terraform. Ainsi il ne sont pas conservé directement dans le code, ni dans le repository. 

Vous pouvez choisir les valeurs que vous souhaitez pour ces variables. La première variable correspond à l'user d'administration de la base de donnée et la seconde au mot de passe.

```sh
$ export TF_VAR_dtt_rds_username=<entrez_ici_la_valeur>
$ export TF_VAR_dtt_rds_password=<entrez_ici_une_autre_valeur>
```

**Générer la paire de clé SSH permettant de se connecter à l'instance EC2**

Il est nécessaire de disposer d'une paire de clé pour se connecter 

```sh
$ ssh-keygen -t ed25519 -f ./dtt_compute_key
```

**Vérifiez la pile**

Nous allons maintenant demander à Terraform de créer un plan d'execution et nous permettre de le visualiser afin de vérifier les opérations qu'ils mettra en oeuvre lors de l'execution effective. Toujours dans le même dossier, entrez la commande suivante :

```sh
$ terraform plan
```

Si tout s'execute normalement, une liste de modification devrait s'afficher après quelques secondes avec la quantité d'éléments à ajouter, modifier et détruire.

_Exemple_
```sh
Plan: 5 to add, 0 to change, 0 to destroy.
```

**Executer les modifications d'infrastructure**

Dans cette partie, nous allons appliquer les modifications d'infrastructure décrites dans le code. 

Toujours dans le même dossier, exécutez la commande suivante :

```sh
$ terraform apply
```

Terraform va rejouer sa séquence de planification et vous indiquer les opérations qu'il va effectuer. Par la suite, il va demander de confirmer l'application de ces actions.

```sh
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
```

Si vous voulez appliquer les modifications sur AWS, entrez `yes`. Dans tout autre cas les modifications seront abandonnées.

Les modifications vont alors se dérouler, ces dernières peuvent prendre plusieurs minutes (la création de la base de donnée plus particulièrement).

### Vérifier l'accès au système de BDD depuis le serveur

Afin de vérifier que l'instance serveur puisse se connecter à la base de donnée, nous allons :
- Nous connecter en SSH sur l'instance EC2
- Installer le client postgresql
- Nous connecter sur la base de donnée RDS PostgreSQL




**Supprimer l'infrastructure**

--

## Méthodologie de réalisation

**Compréhension des attendus**

Dans une premier temps j'ai commencé à extraire du sujet les éléments essentiels afin de me focaliser sur l'attendu et ne pas me disperser.

Sont attendus de moi : 
  - **Une** instance EC2 de format **t4g.micro**
  - **Une** base de donnée **RDS PostgreSQL** de format **db.t4g.micro** 
  - Assurer la communication **depuis** le serveur (instance EC2) **vers** la base de donnée. 
  - La rédaction d'un plan Terraform afin d'executer ces éléments.
  - La documentation associée et ma démarche.












