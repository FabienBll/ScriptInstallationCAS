#!/bin/bash
# Script testé sur Debian 11
# Ce script est uniquement adapté à l'IPv4

clear
if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

echo "------------------- Configuration du serveur DHCP -------------------"
echo ''

paquets=(isc-dhcp-server)

for paquets in "${paquets[@]}"; do
   if $(dpkg -s "$paquets" >/dev/null); then
      echo "$paquets est déjà installé"
   else
      apt install $paquets -y >/dev/null
      echo "Installation de $paquets"
      if $(dpkg -s "$paquets" >/dev/null); then
         echo "$paquets a été installé avec succès."
      else
         echo "Erreur durant l'installation de $paquets" 1>&2
      fi
   fi
done

echo ''
echo "---------------------------------------------------------------------"
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcp_save.conf

echo "default-lease-time 600;" > /etc/dhcp/dhcpd.conf
echo "max-lease-time 7200;" >> /etc/dhcp/dhcpd.conf
echo 'option domain-name "exemple.org" ;' >> /etc/dhcp/dhcpd.conf
echo '' >> /etc/dhcp/dhcpd.conf

# Liste les interfaces réseaux présentes sur la machine
interfaces=$(grep -o "\<iface\>.*" /etc/network/interfaces | awk '{print $2}' | sed 's/lo//' | sed '/^$/d')

# Modife l'interface sur laquelle écoute le DHCP
if [[ -z $interfaces ]]; then
   echo "Erreur, aucune interface réseau n'a été trouvée" 1>&2
   exit 1
else
   verif=0
   while [ $verif -ne 1 ]; do
      read -p "Sélectionnez l'interface réseau sur laquelle écoute le serveur DHCP (${interfaces}) : " interface_dhcp 
      if [[ -n $interface_dhcp ]]; then
         sed "s/INTERFACESv4=\"\"/INTERFACESv4=\"${interface_dhcp}\"/" /etc/default/isc-dhcp-server >/dev/null
         verif=1
      else
         echo "Vous devez choisir une interface réseau." 1>&2
      fi
   done
fi
verif=0
echo "---------------------------------------------------------------------"

while [ $verif -ne 1 ]; do
   read -p "Adresse de réseau pour l'intervalle : " adresse_reseau
   if [[ $adresse_reseau =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      verif=1
   else
      echo "Erreur, adresse IP non valide" 1>&2
   fi
done
verif=0
echo ''

while [ $verif -ne 1 ]; do
   read -p "Masque de sous-réseau (CIDR non prit en charge) : " masque
   if [[ $adresse_reseau =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "subnet ${adresse_reseau} netmask ${masque} {" >> /etc/dhcp/dhcpd.conf
      verif=1
   else
      echo "Erreur, masque de sous-réseau non valide" 1>&2
   fi
done
verif=0
echo ''

while [ $verif -ne 1 ]; do
   read -p "Première adresse de l'intervalle : " debut_intervalle
   if [[ $adresse_reseau =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      verif=1
   else
      echo "Erreur, adresse IP non valide" 1>&2
   fi
done
verif=0
echo ''

while [ $verif -ne 1 ]; do
   read -p "Deuxième adresse de l'intervalle : " fin_intervalle
   if [[ $adresse_reseau =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "  range ${debut_intervalle} ${fin_intervalle};" >> /etc/dhcp/dhcpd.conf
      verif=1
   else
      echo "Erreur, adresse IP non valide" 1>&2
   fi
done
verif=0
echo "---------------------------------------------------------------------"

while [ $verif -ne 1 ]; do 
   read -p "Passerelle (ne rien mettre si vous ne souhaitez pas l'ajouter) : " passerelle
   if [[ $passerelle =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "  option routers ${passerelle};" >> /etc/dhcp/dhcpd.conf
      verif=1
   elif [[ -z $passerelle ]]; then
      verif=1
   else
      echo "Erreur dans l'adresse de la passerelle." 1>&2
   fi
done
verif=0
echo "---------------------------------------------------------------------"

while [ $verif -ne 1 ]; do 
   read -p "Serveur DNS (ne rien mettre si vous ne souhaitez pas l'ajouter) : " dns_server
   if [[ $dns_server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ $dns_server =~ ^*\.*$ ]]; then
      echo "  option domain-name-servers ${dns_server};" >> /etc/dhcp/dhcpd.conf
      verif=1
   elif [[ -z $dns_server ]]; then
      verif=1
   else
      echo "Erreur dans l'adresse du server DNS." 1>&2
   fi
done
verif=0
echo "---------------------------------------------------------------------"

echo "}" >> /etc/dhcp/dhcpd.conf
echo '' >> /etc/dhcp/dhcpd.conf

# Cette boucle a pour but d'ajouter autant de machine que l'on souhaite
read -p "Voulez-vous attribuer une adresse à une machine ? (o/n) : " attribuer_adresse
while [ "$attribuer_adresse" == "o" ]; do

   while [ $verif -ne 1 ]; do
      read -p "Nom de la machine : " nom
      if [[ -n $nom ]]; then
         echo "host ${nom} {" >> /etc/dhcp/dhcpd.conf
         verif=1
      else
         echo "Vous devez donner un nom à la machine" 1>&2
      fi
   done
   verif=0

   while [ $verif -ne 1 ]; do
      read -p "Adresse MAC de la machine : " mac
      if [[ $mac =~ ^[[:alnum:]]{1,2}\:[[:alnum:]]{1,2}\:[[:alnum:]]{1,2}\:[[:alnum:]]{1,2}\:[[:alnum:]]{1,2}\:[[:alnum:]]{1,2}$ ]]; then
         echo "  hardware ethernet ${mac};" >> /etc/dhcp/dhcpd.conf
         verif=1
      else
         echo "Erreur, adresse MAC non valide." 1>&2
      fi
   done

   while [ $verif -ne 1 ]; do
      read -p "Adresse à attribuer à la machine : " add_machine
      if [[ $add_machine =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ $dns_server =~ ^*\.*$ ]]; then
         echo "  fixed-address ${add_machine}" >> /etc/dhcp/dhcpd.conf
         echo "}" >> /etc/dhcp/dhcpd.conf
         echo '' >> /etc/dhcp/dhcpd.conf
      else
         echo "Erreur, adresse IP non valide." 1>&2
      fi
   done

   read -p "Voulez-vous ajouter une autre machine ? (o/n) : " autre_machine
   if [ "$autre_machine" == "n" ]; then
      attribuer_adresse=n
   fi
done

systemctl restart isc-dhcp-server >/dev/null
if [ $? -eq 0 ]; then
   echo "Configuration du DHCP terminée avec succès."
else
   echo "Erreur" 1>&2
fi

echo "---------------------------------------------------------------------"
exit 0

# S'assurer que le DHCP écoute sur une interface configurée en statique
