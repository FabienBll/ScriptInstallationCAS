#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

paquets=(isc-dhcp-server)

for paquets in "${paquets[@]}"; do
   if $(dpkg -s "$paquets" >/dev/null); then
      echo "$paquets est déjà installé"
      if $(dpkg -s "$paquets" >/dev/null); then
         echo "$paquets a été installé avec succès."
      else
         echo "Erreur durant l'installation de $paquets" 1>&2
      fi
   else
      apt install $paquets -y >/dev/null
      echo "Installation de $paquets"
   fi
done

mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.sav
touch /etc/dhcp/dhcpd.conf

# Liste les interfaces réseaux présentes sur la machine
interfaces=$(grep -o "\<iface\>.*" /etc/network/interfaces | awk '{print $2}' | sed 's/lo//g')

# Modife l'interface sur laquelle écoute le DHCP
echo "Sélectionnez l'interfaces réseau sur laquelle écoute le serveur DHCP : "
read -p "(${interfaces})" interface_dhcp
sed "s/INTERFACESv4=\"\"/INTERFACESv4=${interface_dhcp}"

read -p "Adresse de réseau pour l'intervalle : " adresse_reseau
read -p "Masque de sous-réseau (format : 255.255.255.255) : " masque
echo "subnet ${adresse_reseau} netmask ${masque} {" >> /etd/dhcp/dhcpd.conf

read -p "Première adresse de l'intervalle : " debut_intervalle
read -p "Deuxième adresse de l'intervalle : " fin_intervalle
echo "   range ${debut_intervalle} ${fin_intervalle};" >> /etd/dhcp/dhcpd.conf

verif=0
while [ verif -ne 1 ]; do 
   read -p "Passerelle (ne rien mettre si vous ne souhaitez pas l'ajouter)" passerelle
   if [[ $passerelle =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "  option routers ${passerelle};" >> /etd/dhcp/dhcpd.conf
      verif=1
   fi
done
verif=0

while [ verif -ne 1 ]; do 
   read -p "Serveur DNS (ne rien mettre si vous ne souhaitez pas l'ajouter)" dns_server
   if [[ $dns_server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [ "$dns_server" == "*.*" ]; then
      echo "  option domain-name-serves ${dns_server};" >> /etd/dhcp/dhcpd.conf
      verif=1
   elif [[ -n $dns_server ]]; then
      verif=1
   else
      echo "Erreur dans l'adresse du server DNS" 1>&2
   fi
done
verif=0
echo "} \n" >> /etd/dhcp/dhcpd.conf

read -p "Voulez-vous attribuer une adresse à une machine ? (o/n) : " attribuer_adresse
while [ "$attribuer_adresse" == "o" ]; do

   # Cette boucle a pour but d'ajouter autant de machine que l'on souhaite
   while [ $verif -ne 1 ]; do
      read -p "Nom de la machine : " nom
      if [[ -n $nom ]]; then
         echo "host ${nom} {" >> /etd/dhcp/dhcpd.conf
         verif=1
      else
         echo "Vous devez donner un nom à la machine"
      fi
   done
   verif=0

   read -p "Adresse MAC de la machine : " mac
   echo "  hardware ethernet ${mac};" >> /etd/dhcp/dhcpd.conf

   read -p "Adresse à attribuer à la machine : " add_machine
   echo "  fixed-address ${add_machine}" >> /etd/dhcp/dhcpd.conf

   echo "} \n" >> /etd/dhcp/dhcpd.conf

   read -p "Voulez-vous ajouter une autre machine ? (o/n) : " autre_machine
   if [ "$autre_machine" == "n" ]; then
      attribuer_adresse=n
   fi
done
exit 0

# S'assurer que le DHCP écoute sur une interface configurée en statique