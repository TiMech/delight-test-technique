# Test Technique - Création d’une pile Terraform.

_ANDREY Thomas_ / _Janvier 2024_

## Sujet

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

## Déploiement de la pile Terraform

### Pré-requis

**AWS**
Avant toute chose, vous devez disposer d'un compte AWS et des credentials pour y accéder et créer des ressources. 

Assurer-vous que vos credentials soient présents dans le fichier `~/.aws/credentials`. Terraform utilisera ces éléments pour se connecter. Pour plus de précisions à ce sujet, référez vous à la page officielle suivante : https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-short-term.html

**Terraform**
Terraform doit être installé sur votre poste de travail. Veuillez vous référer au lien suivant pour connaitre la démarche à adopter suivant votre configuration : https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

### Préparation du plan

_Il n'est pas nécessaire de réitérer cette étape a chaque application du plan, seulement si un nouveau plugin doit être téléchargé._

Après avoir récupéré les fichiers *.tf qui constituent le plan terraform, l'outil à besoin de récupérer les plugins nécessaires à leur mise en oeuvre. 

Pour cela, ouvrez un terminal de commande et placez vous dans le dossier où sont situés vos fichiers du plan terraform. Entrez la commande ci-dessous pour lancer le téléchargement des plugins.

```sh
$ terraform init
```

Un message de succès devrait apparaitre après le téléchargement et un dossier `.terraform` contenant les nouveaux éléments devrait être créé.

```sh
Terraform has been successfully initialized!
```

**Renseigner les variables d'environnement**

Nous allons entrer les secrets en tant que variable d'environnement pour qu'ils soient utilisés par le plan Terraform. En opérant de cette façon, les secrets ne sont pas conservés directement dans le code, ni remontés dans le repository. 

**Ce procédé est utilisé tel quel pour les besoins de simplicité de l'exercice et ne relève aucunement d'une "best practice" qui nécessiterait de récupérer les secrets depuis des stockages sécurisés (Ex: AWS Secret Manager).**

La première variable correspond à l'utilisateur d'administration de la base de donnée et la seconde au mot de passe. Ces valeurs de test seront réutilisées lors de la connection à la BDD. Entrez les commandes ci-dessous dans la console :

```sh
$ export TF_VAR_dtt_rds_username=test
$ export TF_VAR_dtt_rds_password=delight_pwd
```

_Les commandes Terraform qui vont suivre sont à exécuter dans la même console afin de bénéficier de ces variables d'environnement._

**Générer la paire de clé SSH permettant de se connecter à l'instance EC2**

Pour pouvoir se connecter ultérieurement à notre instance EC2, il est primordial de disposer d'une paire de clés SSH. Lors de la création de l'instace, la clé publique sera délivrée à cette première afin d'autorisé l'accès de l'administrateur détenteur de la clé privée.

**Ce procédé est utilisé tel quel pour les besoins de simplicité de l'exercice et ne relève aucunement d'une "best practice". Elle n'assure pas en tant que tel une sécurité optimale des clés SSH et un travail collaboratif.**

Pour générer la clé utilisée dans ce projet, entrez la commande ci-dessous dans la console, toujours dans le même dossier. Laissez vide la passphrase que le système vous demandera.

```sh
$ ssh-keygen -t ed25519 -f ./dtt_compute_key
```

La paire de clé générées, deux fichiers doivent être apparus dans le dossier : `dtt_compute_key` (clé privée) et `dtt_compute_key.pub` (clé publique).


**Vérifiez la pile**

Nous allons maintenant demander à Terraform de créer un plan d'execution et nous permettre de le visualiser afin de simuler les opérations qu'ils mettra en oeuvre. Toujours dans le même dossier et la même console, entrez la commande suivante :

```sh
$ terraform plan
```

Si tout s'execute normalement, une liste de modification devrait s'afficher après quelques secondes avec la quantité d'éléments à ajouter, modifier et détruire.

_Exemple_
```sh
Plan: 18 to add, 0 to change, 0 to destroy.
```

**Executer les modifications d'infrastructure**

Maintenant que nous avons vérifié la cohérence de notre plan ,il est temps de l'executer. Nous allons appliquer les modifications d'infrastructure décrites dans le code. Toujours dans le même dossier et la même console, entrez la commande suivante :

```sh
$ terraform apply
```

Terraform va rejouer sa séquence de planification et vous indiquer les opérations qu'il va effectuer. Par la suite, il va demander de confirmer l'application de ces actions.

```sh
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
```

Entrez `yes` pour appliquer les créations/modifications du plan. Toute autre réponse entraine un abandon. Les modifications vont alors se dérouler, ces dernières peuvent prendre **plusieurs minutes** (la création de la base de donnée plus particulièrement).

Notez bien les données qui seront générées par les outputs du plan, elles serviront à se connecter avec les instances.

_Exemple de sortie du plan_
```sh
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
```

### Vérifier l'accès au système de BDD depuis le serveur

Afin de vérifier que l'instance serveur puisse se connecter à la base de donnée, nous allons :
- Nous connecter en SSH sur l'instance EC2
- Installer le client postgresql
- Nous connecter sur la base de donnée RDS PostgreSQL

**Connection SSH à l'instance EC2**

Lors de l'execution du plan, une des sortie de données indique quelle commande SSH à exécuter pour se connecter à l'instance EC2 (sortie _connect_to_ssh_). Cette commande est générée dynamiquement selon le DNS public de l'instance. Ce dernier peut être retrouvé sur le dashboard AWS EC2 en cas de problèmes. 

Cette commande prends en paramètre `-i` la clé SSH que vous avez généré précedemment, le nom d'hôte auquel se connecter et `-v` pour lui indiquer d'être verbeux.

_Exemple de sortie du plan_
```sh
connect_to_ssh = "Commande de connection ssh : ssh -i dtt_compute_key ec2-user@ec2-3-238-147-7.compute-1.amazonaws.com -v"
```

Executez la commande, votre os demandera de confirmer la connection vers cette machine dont il ne peut garantir l'authenticité. Répondez `yes`.

```sh
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Vous devriez arriver sur l'invite de commande de la machine cible

```sh
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \_#####\
  ~~     \###|
  ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
   ~~       V~' '->
    ~~~         /
      ~~._.   _/
         _/ _/
       _/m/'
[ec2-user@ip-10-0-1-10 ~]$ 
```

**Installation du client PsotgreSQL sur l'instance EC2**

Maintenant que nous sommes connecté à l'instance EC2, il va nous falloir installer le client postgreSQL afin de pouvoir dialoguer avec le serveur de la base de donnée (l'instance AWS RDS). Exécutez les commandes suivante sur l'instance EC2

```sh
$ sudo yum update
$ sudo yum install postgresql15
```

Vous devriez avoir un message de confirmation

```sh
Installed:
  postgresql15-15.5-1.amzn2023.0.1.aarch64                                               postgresql15-private-libs-15.5-1.amzn2023.0.1.aarch64                                              

Complete!
```

**Test de communication avec la base de donnée depuis l'instance EC2**

Enfin, nous pouvons tester la communication avec la BDD située sur l'instance RDS.
Pour se faire, il nous faut le endpoint de l'instance RDS. Ce dernier est affiché
par les sorties du plan dans la variable `dtt_rds_endpoint`. Vous pouvez également
retrouver cette information sur le dashboard de l'intance RDS.

_Exemple de sortie du plan_
```sh
dtt_rds_endpoint = "terraform-20240129080257926600000001.c08syezqvlqs.us-east-1.rds.amazonaws.com"
```

Maintenant que nous avons ces éléments, il suffit d'executer la commande ci-dessous sur notre instance EC2 en remplaçant `<dtt_rds_endpoint>` par le endpoint retourné par le plan.

```sh
$ psql -h <dtt_rds_endpoint> -U test -d mydb
```

Le serveur de base de donnée devrait vous demander votre mot de passe, entrez le mot de passe défini au départ de ces consignes pour la variable `TF_VAR_dtt_rds_password`. Si vous avez utilisé la valeur fournie dans l'exemple, il s'agit de `delight_pwd`. Attention, rien ne s'affiche quand vous entrez le mot de passe.

```sh
Password for user test: 
```

Une fois validé, vous devriez voir l'invite de la BDD s'afficher. 

```sh
psql (15.5, server 15.4)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, compression: off)
Type "help" for help.

mydb=> 
```

Nous venons de confirmer la bonne communication du serveur vers notre BDD !
Pour sortir, il suffit d'entrer `exit` dans l'invite de la base de donnée et dans l'invite de l'instance EC2

**Supprimer l'infrastructure**

Maintenant que toute notre architecture est en place et testée, nous souhaitons tout supprimer via terraform.

Pour ce faire, toujours dans la console où nous avons appliqué notre plan précedemment, entrez la commande ci-dessous. Si vous avez fermé la console, pensez à bien reparamétrer les variables d'environnement dans la nouvelle.

```sh
$ terraform destroy
```

Terraform va rejouer sa séquence de planification et ses modifications dans le sens inverse et prévoir la destruction des éléments.

```sh
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
```

Entrez `yes` pour appliquer les destructions. Toute autre réponse entraine un abandon. Les modifications vont alors se dérouler, ces dernières peuvent prendre **plusieurs minutes**.

## Méthodologie de réalisation

**Compréhension des attendus**

Dans une premier temps j'ai commencé à extraire du sujet les éléments essentiels afin de me focaliser sur l'attendu et ne pas me disperser.

Sont explicitement attendus de moi : 
  - **Une** instance EC2 de format **t4g.micro**
  - **Une** base de donnée **RDS PostgreSQL** de format **db.t4g.micro** 
  - Assurer la communication **depuis** le serveur (instance EC2) **vers** la base de donnée. 
  - La rédaction d'un plan Terraform afin d'executer ces éléments.
  - La documentation associée et ma démarche.

**Recherche documentaire et conception**

A partir de ce constat, j'ai recherché dans la documentation officielle de Terraform le fonctionnement global de l'outil, ainsi que des exemples divers sur la toile. J'ai complété ces éléments par la documentation AWS afin de bien saisir les concepts de ce provider.

Je suis partis des attendus vers les éléments induits qui ne sont pas mentionnés dans le sujet (VPC, Security groups...) afin d'obtenir une vision d'ensemble. Une fois le que la syntaxe et la méthode de fonctionnement de Terraform sont démystifiées, la compréhension et l'enchainement des briques structurelles à mettre en place est plutôt clair, malgré quelques subtilités. La recherche documentaire effectuée et les essais menés sur des éléments distincts, j'ai imaginé l'architecture finale que je souhaitais atteindre.

**Réalisation**

j'ai construit mon code incrémentalement en mettant en place les briques structurelles pas à pas. A chaque incrément le plan terraform a été testé, appliqué et détruit. J'ai pu ainsi corriger les erreurs de syntaxe ou de conception au fil de l'eau. 

Ont été implémentés dans l'ordre :
- Le VPC
- Les sous-réseaux
- Les security groups
- Les tables de routages
- L'instance RDS Postgresql
- L'instance EC2

La documentation a été produit paralèllement au code. Une fois l'ensemble réalisé, j'ai supprimé tous les éléments de mon poste, récupéré le plan Terraform depuis le dépôt et suivi scrupuleusement chaque étape pour m'assurer qu'aucune erreur ne s'était glissée dans le processus. 

**Conclusion**

L'acquisition des connaissances relatives à Terraform et AWS ainsi que la conception de ce plan n'ont pas soulevé de difficultés. L'architecture restant contenue et simple, elle permet toutefois de toucher du doigt l'étendue des possibilités offertes par l'infrastructure as code, ainsi que d'apercevoir les challenges qui peuvent y être associés. Ce test technique s'est révélé très enrichissant et confirme mon intérêt pour les sujets devops, cloud et IaaC.










