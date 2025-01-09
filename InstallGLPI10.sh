#!/bin/bash
# Ce script a été testé sur Debian 11
# Ce script ne prend pas en charge les réseaux nécessitant la connexion à un proxy
# Supprimer l'ancienne installation de GLPI : ./InstallGLPI10 clean
# Installer GLPI 10 : ./InstallGLPI10 install [port de votre choix utilisé par GLPI (à indiquer obligatoirement)]
# Installer FusionInventory : ./InstallGLPI10 install_fi

if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

if [ $# -lt 1 ]; then
    echo "Vous devez ajouter au moins un paramètre au script (clean, install [port utilé par GLPI], install_fi)."
    exit 1

fi

# Supprime l'ancienne installation de GLPI
suppr_ancienne_install () {
    rep_suppr=(/var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi)
    for rep_suppr in "${rep_suppr[@]}"; do
        if [ -d $rep_suppr ]; then
            rm -r $rep_suppr
        fi
    done
    if [ -f /etc/apache2/sites-available/000-default-save.conf ]; then
        mv /etc/apache2/sites-available/000-default-save.conf /etc/apache2/sites-available/000-default.conf >/dev/null 1>&2
    fi
    shift
}

installation_paquets () {
    clear
    echo -e "\nMise à jour des paquets..."
    apt-get update >/dev/null
    echo "Mise à jour du système..."
    apt-get upgrade -y >/dev/null

    if dpkg -s "curl" >/dev/null 2>&1; then
        echo "curl est déjà installé."
    else
        apt-get install curl -y >/dev/null 2>&1
        echo "Installation de curl."
    fi

    curl -sSL https://packages.sury.org/php/README.txt | bash >/dev/null

    paquets=(apache2 ca-certificates apt-transport-https software-properties-common wget lsb-release php8.1 libapache2-mod-php8.1 php8.1-gd php8.1-intl php8.1-xml php8.1-dom php8.1-mysqli php8.1-curl php8.1-intl php8.1-mbstring php8.1-ldap php8.1-bz2 php8.1-zip)
    for paquets_install in "${paquets[@]}"; do
        if dpkg -s "$paquets_install" >/dev/null 2>&1; then
            echo "$paquets_install est déjà installé."
        else
            apt-get install $paquets_install -y >/dev/null 2>&1
            echo "Installation de $paquets_install."
            if dpkg -s "$paquets_install" >/dev/null 2>&1; then
                echo "$paquets_install a été installé avec succès."
            else
                echo "Erreur durant l'installation de $paquets_install." 1>&2
            fi
        fi
    done
}

telechargement_glpi () {
    echo "Téléchargement de GLPI..."
    wget https://github.com/glpi-project/glpi/releases/download/10.0.6/glpi-10.0.6.tgz >/dev/null
    tar xvzf glpi-10.0.6.tgz -C /var/www >/dev/null
    rm glpi-10.0.6.tgz
}

# Configuration d'Apache et d'un host virtuel pour GLPI
config_apache () {
    if [ ${port_glpi} -eq 80 ]; then
        cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/glpi.conf
        mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default-save.conf
    else
        cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/glpi.conf
        if ! grep -q "Listen ${port_glpi} " /etc/apache2/ports.conf; then
            echo "Listen ${port_glpi} " >> /etc/apache2/ports.conf
        fi
    fi
    sed -i "s/<VirtualHost \*:80>/<VirtualHost \*:${port_glpi}>/g" /etc/apache2/sites-available/glpi.conf
    sed -i "s/\/var\/www\/html/\/var\/www\/glpi/g" /etc/apache2/sites-available/glpi.conf
    sed -i "s/error.log/error-glpi.log/g" /etc/apache2/sites-available/glpi.conf
    sed -i "s/access.log/access-glpi.log/g" /etc/apache2/sites-available/glpi.conf

    if ! grep -q "session.cookie_httponly" /etc/php/8.1/apache2/php.ini; then
        echo "session.cookie_httponly = on" >> /etc/php/8.1/apache2/php.ini
    elif ! grep -q "session.cookie_httponly = on" /etc/php/8.1/apache2/php.ini; then
        sed -i 's/^session\.cookie_httponly.*/session.cookie_httponly = on/' /etc/php/8.1/apache2/php.ini
    fi
}

activation_site () {
    a2ensite glpi >/dev/null
}

config_glpi () {
    if [ ! -d /etc/glpi ]; then
        mkdir /etc/glpi
    fi
    if [ ! -d /var/lib/glpi ]; then
        mkdir /var/lib/glpi
    fi
    if [ ! -d /var/log/glpi ]; then
        mkdir /var/log/glpi
    fi
    mv /var/www/glpi/files/* /var/lib/glpi
    chgrp -R www-data /etc/glpi/ ;
    chgrp -R www-data /var/lib/glpi/
    chgrp -R www-data /var/log/glpi/
    chgrp -R www-data /var/www/glpi/marketplace/

    chmod -R g+w /etc/glpi/
    chmod -R g+w /var/lib/glpi/
    chmod -R g+w /var/log/glpi/
    chmod -R g+w /var/www/glpi/marketplace/

    echo -e "<?php\ndefine('GLPI_CONFIG_DIR', '/etc/glpi/');\n\nif (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {\n   require_once GLPI_CONFIG_DIR . '/local_define.php';\n}" > /var/www/glpi/inc/downstream.php
    echo -e "<?php\ndefine('GLPI_VAR_DIR', '/var/lib/glpi');\ndefine('GLPI_LOG_DIR', '/var/log/glpi');" > /etc/glpi/local_define.php

    export GLPI_CONFIG_DIR=/etc/glpi/
    export GLPI_VAR_DIR=/var/lib/glpi/
    export GLPI_LOG_DIR=/var/log/glpi/
}

redemarrage_services () {
    echo -e "\nRédemarrage des services cron et apache2..."
    systemctl restart cron
    systemctl restart apache2
}

# Récupère le numéro de port passé en argument
for arg; do
    if [[ $arg =~ ^[0-9]+$ ]]; then
        port_glpi=$arg
    fi
done

for arg; do
    if [ "${arg}" == "clean" ]; then
        suppr_ancienne_install
    elif [ "${arg}" == "install" ]; then
        installation_paquets
        telechargement_glpi
        config_apache
        activation_site
        config_glpi
        redemarrage_services
        echo "Pour finir l'installation rendez-vous sur le lien : http://localhost:${port_glpi}"
    fi
done

exit 0
