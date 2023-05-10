# Script permettant de générer des adresses IP
from random import *

regen = 1
while regen == 1:                           # Boucle permettant de générer d'autres adresses IP sans avoir à relancer le script
    f = 0                 
    classe = str(input("Indiquez la classe de l'adresse IP (A,B,C) : "))
    cidr = int(input("Indiquez le CIDR (16,24) : "))
    nbrsr = int(input("Indiquez le nombre de sous-réseaux : "))
    if nbrsr > 255:
        break

    tab = []
    if classe == 'A':
        ip = [10, 16, 0, 0]
    elif classe == 'B':
        ip = [172, 16, 0, 0]
    elif classe == 'C':
        ip = [192, 168, 0, 0]
    else:
        print("Erreur dans le choix de la classe d'IP")

    if cidr == 16:                         # Cette condition permet de définir quelle partie de l'IP sera modifié par la boucle suivante
        a = 1
    elif cidr == 24:
        a = 2
    elif cidr < 0 or cidr > 32:
        print("Ce n'est pas un CIDR")
    else:
        print("Ce CIDR n'est pas encore pris en charge.")

    while f < nbrsr:
        aleatoire = randint(0,255)
        if aleatoire not in tab:            # Cette condition permet d'éviter de générer plusieurs fois la même adresse IP 
            f = f + 1
            print(f, end = " : ")           # Affiche un compteur avant chaque adresse IP
            ip[a] = aleatoire
            for e in range(4):
                print(ip[e], end = '')
                if e <= 2:
                    print(".", end = '')
            print("")
        tab.append(aleatoire)
    
    recommancer = str(input("Voulez-vous en générer d'autres ? (o/n) : "))
    if recommancer == 'o':
        regen = 1
    else:
        regen = 0

