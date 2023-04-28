#!/bin/bash
# Ce script a été testé sur Debian 11
# Ce script ne prend pas en charge les réseaux nécessitant l'utilisation d un proxy
# Supprimer l'ancienne installation de Silverpeas : ./InstallSilverpeas clean
# Installer Silverpeas : ./InstallSilverpeas install

# Vérifie que l'utilisateur est root
if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

# Suppression de l'installation précédente de Silverpeas
if [ "$1" == 'clean' ] ; then 
	if [ -d "/opt/silverpeas-6.3-wildfly26" ] ; then
		rm -r /opt/silverpeas-6.3-wildfly26
	fi
	if [ -d "/opt/wildfly-26.1.2.Final" ] ; then
		rm -r /opt/wildfly-26.1.2.Final
	fi
	if [ -d "~/.gradle/caches/jars-8/*" ] ; then
		rm -r ~/.gradle/caches/jars-8/*
	fi
	if [ -f "/opt/silverpeas-6.3-wildfly26.zip" ] ; then
		rm /opt/silverpeas-6.3-wildfly26.zip*
	fi
	if [ -f "/opt/wildfly-26.1.2.Final.zip" ] ; then
		rm /opt/wildfly-26.1.2.Final.zip*
	fi
fi

# Installation de Silverpeas
if [ "$1" == 'install' ] || [ "$2" == 'install' ] ; then
	clear
	verif=0
	echo "------------------------ Installation de Silverpeas ------------------------"

	# Installation des paquets nécessaires
	paquets=(openjdk-11-jdk unzip)

	for paquets in "${paquets[@]}" 
	do
		if dpkg -s "$paquets" >/dev/null; then
			echo "$paquets est déjà installé."
		else
			apt install $paquets -y >/dev/null
			echo "Installation de $paquets"
			if dpkg -s "$paquets" >/dev/null; then
				echo "$paquets a été installé avec succès"
			else
				echo "Erreur dans l'installation de $paquets"
				exit 1
			fi
		fi
	done

	# Téléchargement et décompression des fichiers pour Wildfly et Silverpeas
	wget -P /opt/ https://www.silverpeas.org/files/wildfly-26.1.2.Final.zip 
	wget -P /opt/ https://www.silverpeas.org/files/silverpeas-6.3-wildfly26.zip

	unzip /opt/silverpeas-6.3-wildfly26.zip -d /opt/ >/dev/null
	unzip /opt/wildfly-26.1.2.Final.zip -d /opt/ >/dev/null

	rm /opt/silverpeas-6.3-wildfly26.zip*
	rm /opt/wildfly-26.1.2.Final.zip*

	# Création des variables d'environnement pour linstallation
	JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
	export JAVA_HOME
	SILVERPEAS_HOME=/opt/silverpeas-6.3-wildfly26
	export SILVERPEAS_HOME
	JBOSS_HOME=/opt/wildfly-26.1.2.Final
	export JBOSS_HOME

	# Création du fichier de configuration
	cp /opt/silverpeas-6.3-wildfly26/configuration/sample_config.properties /opt/silverpeas-6.3-wildfly26/configuration/config.properties
	config='/opt/silverpeas-6.3-wildfly26/configuration/config.properties'

	sed -i 's/#SILVERPEAS/SILVERPEAS/' $config
	sed -i "s/#DB_USER/##DB_USER/" $config
	sed -i 's/#DB_PORT/##DB_PORT/' $config
	sed -i 's/#DB_/DB_/' $config
	
	# Choix du login et du mot de passe
	while [ $verif -ne 1 ] ; do
		echo "----------------------------------------------------------------------------"
		read -p "Indiquez le nom d'utilisateur (compte administrateur) : " login
		if [ "$login" != '' ] ; then
			sed -i "s/SILVERPEAS_ADMIN_LOGIN=SilverAdmin/SILVERPEAS_ADMIN_LOGIN=$login/" $config
			verif=1
		else
			echo "Erreur dans le choix du nom d'utilisateur"
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Choix du mot de passe
	while [ $verif -ne 1 ] ; do
		echo -n "Choisissez un mot de passe pour $login : "
		read -s mdp
		echo ''
		echo -n 'Saisissez à nouveau le mot de passe : '
		read -s mdpv
		echo ''
		if [ "$mdp" == "$mdpv" ] ; then
			sed -i "s/SILVERPEAS_ADMIN_PASSWORD=SilverAdmin/SILVERPEAS_ADMIN_PASSWORD=$mdp/" $config
			verif=1
			mdp=''
			mdpv=''
		else
			echo "Erreur, les mots de passe ne correspondent pas."
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Choix de l'adresse e-mail pour recevoir les notifications de Silverpeas
	while [ $verif -ne 1 ] ; do
		read -p "Indiquez l'adresse e-mail pour les notifications de Silverpeas : " mail
		if [ $mail != '' ] ; then
			sed -i "s/SILVERPEAS_ADMIN_EMAIL=silveradmin@localhost/SILVERPEAS_ADMIN_EMAIL=$mail/" $config
			verif=1
		else
			echo "Erreur dans le format de l'adresse mail"
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Choix de la langue de Silverpeas
	while [ $verif -ne 1 ] ; do
		read -p "Langue de l'interface de Silverpeas (fr, en, de) : " langue
		if [ "$langue" == 'fr' ] || [ "$langue" == 'en' ] || [ "$langue" == 'de' ] ; then
			sed -i "s/SILVERPEAS_USER_LANGUAGE=fr/SILVERPEAS_USER_LANGUAGE=$langue/" $config
			sed -i "s/SILVERPEAS_CONTENT_LANGAGES=fr/SILVERPEAS_CONTENT_LANGAGES=$langue/" $config
			verif=1
		else
			echo 'Erreur dans le choix de la langue'
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Choix de la quantité de RAM attribuée à Java
	while [ $verif -ne 1 ] ; do
		read -p 'Quantité de RAM pour Java (2048Mo minimum, entrez la valeur en Mo et uniquement avec des chiffres) : ' ram
		if [ $ram -ge 2048 ] ; then
			sed -i 's/#JVM/JVM/'  $config
			sed -i "s/JVM_RAM_MAX=2048m/JVM_RAM_MAX=$ram\m/" $config
			verif=1
		else
			echo 'Erreur dans le choix de la quantité de ram.'
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Ajout de la base de données dans le fichier config.properties
	while [ $verif -ne 1 ] ; do
		read -p 'Type de base de données à lier (MSSQL, POSTGRESQL, ORACLE) : ' bdd
		if [ "$bdd" == 'MSSQL' ] || [ "$bdd" == 'POSTGRESQL' ] || [ "$bdd" == 'ORACLE' ] ; then
			sed -i "s/DB_SERVERTYPE=POSTGRESQL/DB_SERVERTYPE=$bdd/" $config
			sed -i "s/#DB_PORT_$bdd/DB_PORT_$bdd/" $config
			verif=1
		else
			echo "Erreur dans le choix de la base de données"
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Ajout de l'adresse de la base de données
	while [ $verif -ne 1 ] ; do
		echo -n "Adresse de la base de données : "
		read adBdd
		if [[ $adBdd =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [ "$adBdd" == 'localhost' ] ; then
			sed -i "s/DB_SERVER=localhost/DB_SERVER=$adBdd/" $config
			verif=1
		else
			echo "Erreur dans l'adresse de la base de données."
		fi	
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Ajout du login de connexion à la base de données
	read -p "Login de la base de données" logBdd
	if [ "$logBdd" != '' ] ; then
		sed -i "s/#DB_USER=postgres/DB_USER=$logBdd/" $config
	fi
	echo "----------------------------------------------------------------------------"

	# Ajout du nom de la base de données
	while [ $verif -ne 1 ] ; do
		read -p 'Nom de la base de données : ' nomBdd
		if [ "$nomBdd" != '' ] ; then
			sed -i "s/DB_NAME=postgres/DB_NAME=$nomBdd/" $config
			verif=1
		else
			echo "Erreur dans le nom de la base de données"
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Ajout du mot de passe d'accès à la base de données
	while [ $verif -ne 1 ] ; do
		echo -n "Indiquez le mot de passe d'accès à la base de données $mdpBdd : "
		read -s mdpBdd
		echo ''
		echo -n 'Saisissez à nouveau le mot de passe : '
		read -s mdpBddV
		echo ''
		if [ "mdpBdd" == ''] && [ "mdpBddV" == ''] ; then
			sed -i "s/DB_PASSWORD/#DB_PASSWORD/" $config
		elif [ "$mdpBdd" == "$mdpBddV" ] ; then
			sed -i "s/DB_PASSWORD=postgres/DB_PASSWORD=$mdpBdd/" $config
			verif=1
			mdpBdd=''
			mdpBddV=''
		else
			echo "Erreur, les mots de passe ne correspondent pas."
		fi
	done
	echo "----------------------------------------------------------------------------"
	verif=0

	# Lancement de l'installation de Silverpeas
	while [ $verif -ne 1 ] ; do
		read -p "Lancer l'installation de Silverpeas (o/n) : " install
		echo "----------------------------------------------------------------------------"
		if [ "$install" == 'o' ] ; then
			bash /opt/silverpeas-6.3-wildfly26/bin/silverpeas clean install
			bash /opt/silverpeas-6.3-wildfly26/bin/silverpeas start
			echo 'Installation terminée, vous pouvez vérifier via le lien : http://localhost:8000/'
			verif=1
		elif [ "$install" == 'n' ] ; then
			echo "Vous pouvez éditer le fichier de configuration : $config"
			verif=1
		else
			echo 'Veuillez entrer o ou n.'
		fi
	done
	verif=0

fi
exit 0
