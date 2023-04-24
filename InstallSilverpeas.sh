#!/bin/bash
# Ce script a été testé sur Debian 11
# Ce script ne prend pas en charge les réseaux nécessitant l'utilisation d un proxy
# Supprimer l'ancienne installation de Silverpeas : ./InstallSilverpeas clean
# Installer Silverpeas : ./InstallSilverpeas install
# Supprimer et installer : ./InstallSilverpeas clean install

verif=0

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
fi

if [ "$1" == 'install' ] || [ "$2" == 'install' ] ; then

	# Installation des paquets nécessaires
	apt install openjdk-11-jdk unzip -y

	JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
	export JAVA_HOME

	# Téléchargement et décompression des fichiers pour Wildfly et Silverpeas
	wget -P /opt/ https://www.silverpeas.org/files/wildfly-26.1.2.Final.zip 
	wget -P /opt/ https://www.silverpeas.org/files/silverpeas-6.3-wildfly26.zip

	unzip /opt/silverpeas-6.3-wildfly26.zip -d /opt/
	unzip /opt/wildfly-26.1.2.Final.zip -d /opt/

	rm /opt/silverpeas-6.3-wildfly26.zip*
	rm /opt/wildfly-26.1.2.Final.zip*

	# Création des variables d'environnement pour linstallation
	SILVERPEAS_HOME=/opt/silverpeas-6.3-wildfly26
	export SILVERPEAS_HOME
	JBOSS_HOME=/opt/wildfly-26.1.2.Final
	export JBOSS_HOME

	# Création du fichier de configuration
	cp /opt/silverpeas-6.3-wildfly26/configuration/sample_config.properties /opt/silverpeas-6.3-wildfly26/configuration/config.properties
	config='/opt/silverpeas-6.3-wildfly26/configuration/config.properties'

	sed -i 's/#SILVERPEAS/SILVERPEAS/' $config
	sed -i 's/#DB_PORT/##DB_PORT/' $config
	sed -i 's/#DB_/DB_/' $config
	
	# Choix du login et du mot de passe
	while [ $verif -ne 1 ] ; do
		read -p "Indiquez le nom d'utilisateur (compte administrateur) : " login
		if [ "$login" != '' ] ; then
			sed -i "s/SILVERPEAS_ADMIN_LOGIN=SilverAdmin/SILVERPEAS_ADMIN_LOGIN=$login/" $config
			verif=1
		else
			echo "Erreur dans le choix du nom d'utilisateur"
		fi
	done
	verif=0

	# Choix du mot de passe
	while [ $verif -ne 1 ] ; do
		echo "Choisissez un mot de passe pour $login : "
		read -s mdp
		echo 'Saisissez à nouveau le mot de passe : '
		read -s mdpv
		if [ "$mdp" == "$mdpv" ] ; then
			sed -i "s/SILVERPEAS_ADMIN_PASSWORD=SilverAdmin/SILVERPEAS_ADMIN_PASSWORD=$mdp/" $config
			verif=1
			mdp=''
			mdpv=''
		else
			echo "Erreur, les mots de passe ne correspondent pas."
		fi
	done
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
	verif=0

	# Ajout de la base de données dans le fichier config.properties
	while [ $verif -ne 1 ] ; do
		read -p 'Type de base de données à lier (MSSQL, POSTGRESQL, ORACLE) : ' bdd
		if [ "$bdd" == 'MSSQL' ] || [ "$bdd" == 'POSTGRESQL' ] || [ "$bdd" == 'ORACLE' ] ; then
			sed -i "s/#DB_SERVERTYPE=POSTGRESQL/DB_SERVERTYPE=$bdd/" $config
			sed -i "s/#DB_PORT_$bdd/DB_PORT_$bdd/" $config
			verif=1
		else
			echo "Erreur dans le choix de la base de données"
		fi
	done
	verif=0

	# Ajout de l'adresse de la base de données
	while [ $verif -ne 1 ] ; do
		read -p 'Adresse de la base de données : ' adBdd
		if [ $adBdd != '' ] || [[ $adBdd =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
			sed -i "s/#DB_SERVER=localhost/DB_SERVER=$adBdd/" $config
			verif=1
		else
			echo "Erreur dans l'adresse de la base de données"
		fi
	done
	verif=0

	# Ajout du login de connexion à la base de données
	while [ $verif -ne 1 ] ; do
		read -p 'Adresse de la base de données : ' logbdd
		if [ "$logbdd" != '' ] ; then
			sed -i "s/#DB_USER=Silverpeas/DB_USER=$logbdd/" $config
			verif=1
		else
			echo "Erreur dans le login d'accès à la base de données"
		fi
	done
	verif=0

	# Ajout du nom de la base de données
	while [ $verif -ne 1 ] ; do
		read -p 'Nom de la base de données : ' nomBdd
		if [ "$nomBdd" != '' ] ; then
			sed -i "s/#DB_NAME=Silverpeas/DB_NAME=$nomBdd/" $config
			verif=1
		else
			echo "Erreur dans le nom de la base de données"
		fi
	done
	verif=0

	# Ajout du mot de passe d'accès à la base de données
	while [ $verif -ne 1 ] ; do
		echo "Indiquez le mot de passe d'accès à la base de données $nomBdd : "
		read -s mdpBdd
		echo 'Saisissez à nouveau le mot de passe : '
		read -s mdpBddV
		if [ "$mdpBdd" == "$mdpBddV" ] ; then
			sed -i "s/SILVERPEAS_ADMIN_PASSWORD=SilverAdmin/SILVERPEAS_ADMIN_PASSWORD=$mdpBdd/" $config
			verif=1
			mdpBdd=''
			mdpBddV=''
		else
			echo "Erreur, les mots de passe ne correspondent pas."
		fi
	done
	verif=0

	# Lancement de l'installation de Silverpeas
	while [ $verif -ne 1 ] ; do
		read -p "Lancer l'installation de Silverpeas (o/n) : " install
		if [ "$install" == 'o' ] ; then
			bash /opt/silverpeas-6.3-wildfly26/bin/silverpeas install
			bash /opt/silverpeas-6.3-wildfly26/bin/silverpeas start
			echo 'Installation terminée, vous pouvez vérifier via le lien : http://localhost:8000/'
			verif=1
		elif [ "$install" == 'n' ] ; then
			echo "Vous pouvez éditer le fichier de configuration : $config"
			verif=1
		else
			echo 'Veuillez entrer y ou n.'
		fi
	done
	verif=0

fi
exit 0