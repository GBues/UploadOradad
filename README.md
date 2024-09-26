# UploadOradad
Script de génération et d'envoi des Audits ORADAD

<#
.SYNOPSIS
	Ce script permet de gérer ORADAD et l'envoi/réception des fichiers vers l'ANSSI

.PARAMETER domain (Obligatoire)
    Nom du domaine, pour filtrer les mla envoyés à l'ANSSI.
.PARAMETER generateAndUpload (Optionel)
    Booléen Génère le mla et l'envoi sur le site de l'ANSSI
.PARAMETER DownLoadResults (Optionel)
    Booléen mettre à 1 pour télécharger les résultats sur le site de l'ANSSI. Parcours les fichiers .isSend dans le dossier d'installion d'ORADAD
.PARAMETER UpdateORADAD (Optionel)
    Booléen Télécharge la dernière version d'ORADAD (avant de lancer la génération si generateAndUpload est égalemet à 1)

.EXAMPLE
    Mettre à jour ORADAD depuis le GITHUB ANSSI, générer le MLA et l'envoyer à l'ANSSI pour le domaine contoso.com:
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -UpdateORADAD 1 -generateAndUpload 1 -domain contoso.com
.EXAMPLE
    Utiliser ORADAD installé dans c:\temp\oradad et l'envoyer à l'ANSSI pour le domaine contoso.com
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -generateAndUpload 1 -domain contoso.com
.EXAMPLE
    Récupérer les fichiers .zed des rapports envoyés (à executer le lendemain par exemple)
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -DownLoadResults 1 -domain contoso.com

.VERSION
	v0.0, 27/03/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v0.5, 29/03/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v0.9, 03/05/2024 (UPDATE THE VERSION VARIABLE BELOW)
	
.AUTHOR
	Guillaume Bues
	
.DESCRIPTION
    Ce script se compose de 3 parties :
	- MAJ ORADAD depuis le Github de l'ANSSI !!! Risque de perte des vos fichiers de config
	- Génération du rapport et récuprétion du mla basé sur la date de création + nom du domaine
    - téléchargement du .zed basé sur un témoin d'envoi

    Il faut modifier certains paramètres directement dans le script
.TODO
	
.KNOWN ISSUES/BUGS
	
.RELEASE NOTES
    v0.0, 
        - Première version
    v0.5,
        - Ajout de l'option de téléchargement des fichiers .zed
        - Refonte des appels aux fonctions web et gestion authentification proxy intégrée
        - utilisation de paramètres pour piloter le script plutot que par variables internes
    v0.9,
        - Modification des exemples
        - Version Beta soumise sur OSMOSE
.NOTES
	- Un log est généré dans $ORADADInstallPath
    - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-7.4
#>
