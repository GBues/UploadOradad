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
    v0.9.1,
        - Suite retours du CHIC CM, Merci Thierry Agon
        - Pour les DC en 2012R2, ajout la ligne suivante  à la fonction BuildAndInvokeWebRequest pour forcer le TLS1.2 : [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        - Gestion du cas ou la fonctionnalité IE est supprimé du DC, on ajoute du commutateur -UseBasicParsing à l’appel Invoke-WebRequest
.NOTES
	- Un log est généré dans $ORADADInstallPath
    - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-7.4
#>



param(  [boolean] $DownLoadResults , 
        [boolean] $UpdateORADAD , 
        [boolean] $generateAndUpload ,
        [Parameter(mandatory=$True)] [string] $domain 
) 

#################################################################
# Infos ORADAD

#ORADADInstallPath : Chemin dans lequel sont présents les executables ORADAD
$ORADADInstallPath = "c:\temp\Oradad\"

#ORADADMLADomain : le domaine pour filtrer les mla
$ORADADMLADomain   = $domain


##################################################################
# Infos Club SSI

$CLUBSSIUser                 = "user@domain.fr"
$CLUBSSIPass                 = "LeMotDePasse"

#Ne pas modifier : adresse d'upload cote ANSSI
$CLUBSSIUploadUrl            = "https://club.ssi.gouv.fr/post_oradad.mp"
#Ne pas modifier : nom du champ d'upload cote ANSSI
$CLUBSSIFieldName            = "file"

#TimeOut d'upload du fichier
$CLUBSSIUploadTimeOutMinutes = 10


##################################################################
#Pour utiliser un proxy positionner à $True
$UseProxy = $True

#Infos du proxy
$PROXY           = "http://proxy.contoso.com:8080"

#Si le Proxy gère l'authentification intégrée mettre à $True
$ProxyUseIntegratedAuthentForCurrentUser = $True

# Ne positionner que si ProxyUseIntegratedAuthentForCurrentUser est à $False
$PROXYUser       = "domain\user"
$PROXYPassword    = "C'estMieuxEnAuthentIntégrée!"


##################################################################


# Démarrage du Log
Start-Transcript -Path "$($ORADADInstallPath)\OradadAutoGenerate_$($domain).log"

Write-Output "#########################################"
Write-Output "Paramètres :"
Write-Output "DownLoadResults   : $($DownLoadResults)"
Write-Output "UpdateORADAD      : $($UpdateORADAD)"
Write-Output "generateAndUpload : $($generateAndUpload)"
Write-Output "domain            : $($domain)"
Write-Output "#########################################"

Function getHeaders($user, $password) {
        $pair = "$($user):$($password)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

        $Headers = @{
            Authorization = "Basic $encodedCreds"
        }

        return $Headers
}


Function BuildAndInvokeWebRequest($url, $useProxy, $proxy, $useDefaultcredential, $proxyuser, $proxyPassword, $basicAuthUser, $basicAuthPassword, $outFile) {
        
        #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        #v0.9.1 Si DC en 2012R2 forcer TLS1.2, Merci Tierry Agon CHIC CM, non activé par défaut ;)

        $command = "Invoke-WebRequest -Uri `$url -UseBasicParsing "
        #v0.9.1 -UseBasicParsing : permet de fonctionner Si la fonctionnalité IE avait été supprimé du DC, Merci Tierry Agon CHIC CM

        if($useProxy) {
            if($useDefaultcredential) {
                $command += " -proxy `$proxy -ProxyUseDefaultCredentials"
            } else {
                $encryptedPass = ConvertTo-SecureString $proxyPassword -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $proxyuser, $encryptedPass

                $command += " -proxy `$proxy -ProxyCredential `$cred"
            }
        }

        if($basicAuthUser) {
            $headers = getHeaders -user $basicAuthUser -password $basicAuthPassword

            $command += " -Headers `$headers"
        }

        if($outFile) {
            $command += " -outFile `$outFile"
        }

        return Invoke-Expression $command

}



if($DownLoadResults) {
    $fichiersEnvoyes = Get-ChildItem -Path "$($ORADADInstallPath)\$($ORADADMLADomain)*.isSend"

    foreach($fichier in $fichiersEnvoyes) {
    $fichier
        $zedFile = $fichier.Name.Replace(".mla.isSend",".zed")
        $destFile = $fichier.FullName.Replace(".mla.isSend",".zed")
        $temoinReceivedFile = $fichier.FullName.Replace(".isSend",".isReceived")
        $downloadZed = "https://club.ssi.gouv.fr/download/$zedFile"

        BuildAndInvokeWebRequest -url $downloadZed  -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -basicAuthUser $CLUBSSIUser -basicAuthPassword $CLUBSSIPass -proxyuser $PROXYUser -proxyPassword $PROXYPassword -outFile $destFile

        if(Test-Path $destFile) {
            Rename-Item -Path $fichier -NewName $temoinReceivedFile
        }
    }
}


if($UpdateORADAD) {
    #Récupération de la dernière version sur GitHub

    $repo = "ANSSI-FR/ORADAD"
    $file = "ORADAD.zip"

    $releases = "https://api.github.com/repos/$repo/releases"

    #$tag = ((BuildAndInvokeWebRequest -url $releases -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -basicAuthUser $CLUBSSIUser -basicAuthPassword $CLUBSSIPass -proxyuser $PROXYUser -proxyPassword $PROXYPassword)| ConvertFrom-Json)[0].tag_name
    $response = BuildAndInvokeWebRequest -url $releases -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -basicAuthUser $CLUBSSIUser -basicAuthPassword $CLUBSSIPass -proxyuser $PROXYUser -proxyPassword $PROXYPassword
    $tag = ((ConvertFrom-Json $([String]::new($response.Content)))[0]).tag_name

    Write-Output "Dernière release : $tag"

    $download = "https://github.com/$repo/releases/download/$tag/$file"
    $name = $file.Split(".")[0]
    $zip = "$ORADADInstallPath\$name-$tag.zip"
    $dir = "$ORADADInstallPath\$name-$tag"

    if(-not (Test-Path -Path $dir\oradad.exe -PathType Container)) {
        #Si le dossier d'install n'est pas présent on le crée
        if(-not (Test-Path -Path $ORADADInstallPath -PathType Container)) {
            mkdir -Path $ORADADInstallPath -Force
        }

        Write-Output "Téléchargement dernière release"
        Try {
        BuildAndInvokeWebRequest -url $download -outFile $zip -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -basicAuthUser $CLUBSSIUser -basicAuthPassword $CLUBSSIPass -proxyuser $PROXYUser -proxyPassword $PROXYPassword
        
        Write-Output "Extraction dernière release"
        Expand-Archive $zip -DestinationPath $dir -Force

        Move-Item -Path "$dir/oradad.exe" -Destination "$($ORADADInstallPath)/oradad.exe" -Force

        # Removing temp files
        Remove-Item $zip -Force
        Remove-Item $dir -Force -Recurse
        }
        Catch {
    
            Write-Output "Erreur lors de la récupération de la dernière version d'ORADAD"
            Write-Output $_
            exit 1
        }

    } else {
        Write-Output "Dernière release déja dispo dans $ORADADInstallPath"
    }

    $pathORADAD = $ORADADInstallPath
} else {
    $pathORADAD = $ORADADInstallPath
}


if($generateAndUpload) {

    Write-Output "Lancement du process ORADAD: $($pathORADAD)\ORADAD.exe"
    if(Test-Path -Path "$($pathORADAD)\ORADAD.exe") {
        $processORADAD = Start-Process -FilePath "$pathORADAD\ORADAD.exe" -WorkingDirectory $pathORADAD -PassThru -Wait
    } else {
        Write-Output "Erreur : $($pathORADAD)\ORADAD.exe n'est pas accessible"
        exit 1
    }

    #TODO vérifier les droits d'écriture pour le .mla

    if($processORADAD.ExitCode -ne 0) {
        Write-Output "Une erreur est intervenue dans ORADAD, exitCode: $($processORADAD.ExitCode)"
        exit 1
    }

    
    $lastMLAForDomain = Get-ChildItem -Path "$($pathORADAD)\$($ORADADMLADomain)_*.mla" | sort LastWriteTime | select -last 1

    write-output "Fichier généré : $lastMLAForDomain"

    Try {
        Add-Type -AssemblyName 'System.Net.Http'

        $pair = "$($CLUBSSIUser):$($CLUBSSIPass)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

        $httpClientHandler = New-Object System.Net.Http.HttpClientHandler
    
        if($UseProxy) {
            $httpClientHandler.UseProxy = $UseProxy;
            $WebProxy = New-Object System.Net.WebProxy($PROXY,$true)
            $httpClientHandler.proxy=$webproxy

            if($ProxyUseIntegratedAuthentForCurrentUser) {
                $httpClientHandler.proxy.UseDefaultCredentials = $True
            } else {
                $httpClientHandler.proxy.UseDefaultCredentials = $False
                $encryptedPass = ConvertTo-SecureString $PROXYPassword -AsPlainText -Force
            
                $httpClientHandler.proxy.Credentials = New-Object System.Net.NetworkCredential($PROXYUser, $encryptedPass)
            }
        } 

        $client = New-Object System.Net.Http.HttpClient $httpClientHandler
        $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $encodedCreds);
        $client.Timeout = New-TimeSpan -Minutes $CLUBSSIUploadTimeOutMinutes

        $content = New-Object System.Net.Http.MultipartFormDataContent
        $fileStream = [System.IO.File]::OpenRead($lastMLAForDomain)
        $fileName = [System.IO.Path]::GetFileName($lastMLAForDomain)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add($fileContent, $CLUBSSIFieldName, $fileName)

        $result = $client.PostAsync($CLUBSSIUploadUrl, $content).Result
        $result.EnsureSuccessStatusCode()

        Out-File -FilePath "$lastMLAForDomain.isSend"
    }
    Catch {
    
        Write-Output "Erreur lors de l'upload vers $CLUBSSIUploadUrl"
        Write-Output $_
        exit 1
    }
    Finally {
        if ($client -ne $null) { $client.Dispose() }
        if ($content -ne $null) { $content.Dispose() }
        if ($fileStream -ne $null) { $fileStream.Dispose() }
        if ($fileContent -ne $null) { $fileContent.Dispose() }
    }
}


Stop-Transcript