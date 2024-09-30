# UploadOradad
Script de génération et d'envoi des Audits ORADAD.

<B>NOTA : Script créé rapidement pour usage personnel à l'origine.</B>

<#
.SYNOPSIS<br/>
	Ce script permet de gérer ORADAD et l'envoi/réception des fichiers vers l'ANSSI<br/>

.PARAMETER domain (Obligatoire)<br/>
    Nom du domaine, pour filtrer les mla envoyés à l'ANSSI.<br/>
.PARAMETER generateAndUpload (Optionel)<br/>
    Booléen Génère le mla et l'envoi sur le site de l'ANSSI<br/>
.PARAMETER DownLoadResults (Optionel)<br/>
    Booléen mettre à 1 pour télécharger les résultats sur le site de l'ANSSI. Parcours les fichiers .isSend dans le dossier d'installion d'ORADAD<br/>
.PARAMETER UpdateORADAD (Optionel)<br/>
    Booléen Télécharge la dernière version d'ORADAD (avant de lancer la génération si generateAndUpload est égalemet à 1)<br/>
<br/>
.EXAMPLE<br/>
    Mettre à jour ORADAD depuis le GITHUB ANSSI, générer le MLA et l'envoyer à l'ANSSI pour le domaine contoso.com:<br/>
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -UpdateORADAD 1 -generateAndUpload 1 -domain contoso.com<br/>
.EXAMPLE<br/>
    Utiliser ORADAD installé dans c:\temp\oradad et l'envoyer à l'ANSSI pour le domaine contoso.com<br/>
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -generateAndUpload 1 -domain contoso.com<br/>
.EXAMPLE<br/>
    Récupérer les fichiers .zed des rapports envoyés (à executer le lendemain par exemple)<br/>
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -DownLoadResults 1 -domain contoso.com<br/>
<br/>
.VERSION<br/>
 v0.0, 27/03/2024 (UPDATE THE VERSION VARIABLE BELOW)<br/>
 v0.5, 29/03/2024 (UPDATE THE VERSION VARIABLE BELOW)<br/>
 v0.9, 03/05/2024 (UPDATE THE VERSION VARIABLE BELOW)<br/>
<br/>
.AUTHOR<br/>
	Guillaume Bues<br/>
	
.DESCRIPTION<br/>
	Ce script se compose de 3 parties :<br/>
    	- MAJ ORADAD depuis le Github de l'ANSSI !!! Risque de perte des vos fichiers de config<br/>
 	- Génération du rapport et récuprétion du mla basé sur la date de création + nom du domaine<br/>
  	- téléchargement du .zed basé sur un témoin d'envoi<br/>

	Il faut modifier certains paramètres directement dans le script<br/>
.TODO<br/>
	
.KNOWN ISSUES/BUGS<br/>
	
.RELEASE NOTES<br/>
	v0.0,<br/>
 		- Première version<br/>
   	v0.5,<br/>
    		- Ajout de l'option de téléchargement des fichiers .zed<br/>
      		- Refonte des appels aux fonctions web et gestion authentification proxy intégrée<br/>
		- utilisation de paramètres pour piloter le script plutot que par variables internes<br/>
  	v0.9,<br/>
   	- Modification des exemples<br/>
    	- Version Beta soumise sur OSMOSE<br/>
         v0.9.1,<br/>
        - Suite retours du CHIC CM, Merci Thierry Agon<br/>
        - Pour les DC en 2012R2, ajout la ligne suivante  à la fonction BuildAndInvokeWebRequest pour forcer le TLS1.2 : [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12<br/>
        - Gestion du cas ou la fonctionnalité IE est supprimé du DC, on ajoute du commutateur -UseBasicParsing à l’appel Invoke-WebRequest<br/>
     
.NOTES<br/>
	- Un log est généré dans $ORADADInstallPath<br/>
 	- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-7.4<br/>
#>
