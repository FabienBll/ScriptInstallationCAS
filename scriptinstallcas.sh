#!/bin/bash
# Script d'installation de l'overlay d'Apereo CAS sur Debian 11

# Vérifie si l'utilisateur est bien root (administrateur)
if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list

# Vérifie si le paquet à installer est déjà installé
packages=(tomcat9 tomcat9-admin tomcat9-user openjdk-11-jdk openjdk-11-jre maven build-essential git)

# Installe les paquets
apt update
apt upgrade
for package in "${packages[@]}"
do
    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "Le paquet $package est déjà installé"
    else
        apt install -y "$package"
        if dpkg -s "$package" >/dev/null 2>&1; then
            echo "Le paquet $package a été installé avec succès"
        else
            echo "Erreur lors de l'installation du paquet $package" >&2
            exit 1
        fi
    fi
done

echo "JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/" >> /etc/environment

source /etc/environment

# Rajoute la position de l'installation de Java 11 dans le fichier /etc/default/tomcat9
sed -i '/JAVA_OPTS="-Djava.awt.headless=true"/a JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' /etc/default/tomcat9

sed -i 's|<\/tomcat-users>|<role rolename="admin-gui"\/>\n<user username="admin" password="toor" roles="manager-gui,admin-gui"\/>\n<\/tomcat-users>|' /etc/tomcat9/tomcat-users.xml

systemctl restart tomcat9

wget -P /opt/ https://github.com/apereo/cas-overlay-template/archive/refs/heads/6.6.zip

apt install unzip

unzip /opt/6.6.zip -d /opt/

rm -r /opt/6.6.zip

# Rajoute des implementation nécessaire pour la suite dans le fichier build.gradle

touch /opt/cas-overlay-template-6.6/etc/cas/config/cas.properties

echo "test" > /opt/cas-overlay-template-6.6/etc/cas/config/cas.properties
sed -i 's|test|cas.server.name=http://localhost:8080\ncas.server.prefix=\${cas.server.name}/cas\nlogging.config: file:/etc/cas/config/log4j2.xml ### Desactivation des comptes locaux\n\ncas.authn.accept.users=\n### Connexion LDAP\ncas.authn.ldap\[0\].providerClass=org.ldaptive.provider.unboundid.UnboundIDProvider\ncas.authn.ldap\[0\].type=AUTHENTICATED\ncas.authn.ldap\[0\].useSsl=false\ncas.authn.ldap\[0\].ldapUrl=ldap://localhost:389\ncas.authn.ldap\[0\].baseDn= dc= localhost,dc=fr\ncas.authn.ldap\[0\].subtreeSearch=true\ncas.authn.ldap\[0\].searchFilter=sAMAccountName=\{user\}\ncas.authn.ldap\[0\].principalAttributeList=cn,givenName,mail\n\n### Credential to connect to LDAP\ncas.authn.ldap\[0\].bindDn=CN=Admincas,CN=CasAdmin,DC= localhost,DC=fr\ncas.authn.ldap\[0\].bindCredential=P@ssW0rd|' /opt/cas-overlay-template-6.6/etc/cas/config/cas.properties

mkdir /var/log/cas

chown -R tomcat:adm /var/log/cas

sed -i 's#<Property name="baseDir">/var/log</Property>#<Property name="baseDir">/var/log/cas</Property>#' /opt/cas-overlay-template-6.6/etc/cas/config/log4j2.xml

# Installation de Gradle

cd /opt/cas-overlay-template-6.6/

bash /opt/cas-overlay-template-6.6/gradlew clean

bash /opt/cas-overlay-template-6.6/gradlew clean copyCasConfiguration build

bash /opt/cas-overlay-template-6.6/gradlew createKeystore

cp /opt/cas-overlay-template-6.6/build/libs/cas.war /var/lib/tomcat9/webapps/

systemctl restart tomcat9.service
# Vérifiez si le script à fonctionner en rentrant le lien suivant dans un navigateur : http://localhost:8080/cas/login

# L'identifiant par défaut est : casuser
# Le mode de passe par défaut est : Mellon