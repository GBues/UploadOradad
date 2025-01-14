<#
.SYNOPSIS
	Ce script permet de gérer ORADAD et l'envoi/réception des fichiers vers l'ANSSI

.PARAMETER domain (Obligatoire)
    Nom du domaine, pour filtrer les mla envoyés à l'ANSSI.
.PARAMETER generateAndUpload (Optionel)
    Booléen Génère le mla et l'envoi sur le site de l'ANSSI
.PARAMETER UpdateORADAD (Optionel)
    Booléen Télécharge la dernière version d'ORADAD (avant de lancer la génération si generateAndUpload est égalemet à 1)

.EXAMPLE
    Mettre à jour ORADAD depuis le GITHUB ANSSI, générer le MLA et l'envoyer à l'ANSSI pour le domaine contoso.com:
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -UpdateORADAD -generateAndUpload -domain contoso.com
.EXAMPLE
    Utiliser ORADAD installé dans c:\temp\oradad et l'envoyer à l'ANSSI pour le domaine contoso.com
    powershell.exe -command "<path>\OradadAutoGenerate.ps1" -generateAndUpload -domain contoso.com


.VERSION
	v0.0, 27/03/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v0.5, 29/03/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v0.9, 03/05/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v0.9.1, 30/09/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v1.0, 20/12/2024 (UPDATE THE VERSION VARIABLE BELOW)
    v1.1, 06/01/2025 (UPDATE THE VERSION VARIABLE BELOW)
	
.AUTHOR
	Guillaume Bues
	
.DESCRIPTION
    Ce script se compose de 3 parties :
	- MAJ ORADAD depuis le Github de l'ANSSI !!! Risque de perte des vos fichiers de config
	- Génération du rapport et récuprétion du mla basé sur la date de création + nom du domaine

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
        - Pour les DC en 2012R2, ajout la ligne suivante à la fonction BuildAndInvokeWebRequest pour forcer le TLS1.2 : [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, à décommenter à la main
        - Gestion du cas ou la fonctionnalité IE est supprimé du DC, on ajoute du commutateur -UseBasicParsing à l’appel Invoke-WebRequest
    v1.0,
        - Gestion du nouveau système de Token du nouveau site club-SSI
        - Suppression de la fonction de téléchargement suite à la dispo des rapports sur le nouveau site et nouveau fonctionnement
    v1.1,
        - Ajout du parametre --force pour gérer l'obsolence potentielle de l'EXE oradad (ORADAD autoteste son "age", si pas de version publiée sir le GITHUB on est sur un cas de blocage)
        - Utilisation d'un switch pour les paramètres generateAndUpload et UpdateORADAD
        - possibilité d'utiliser un tableau de domaines
.NOTES
	- Un log est généré dans $ORADADInstallPath
    - https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-7.4
    - https://github.com/ANSSI-FR/ORADAD
#>



param(  [switch] $UpdateORADAD , 
        [switch] $generateAndUpload ,
        [Parameter(mandatory=$True)] [string] $ORADADInstallPath ,
        [Parameter(mandatory=$True)] [string[]] $domain 
) 



##################################################################
# Infos Club SSI
$CLUBSSI_SESSION_GUID = ""
$CLUBSSI_SESSION_UploadToken = ""


#Ne pas modifier : adresse d'upload cote ANSSI
$CLUBSSIUploadUrl            = "https://club.ssi.gouv.fr/upload.mp?ZKBEID=$($CLUBSSI_SESSION_GUID)"
#Ne pas modifier : nom du champ d'upload cote ANSSI
$CLUBSSIFieldName            = "file"

#TimeOut d'upload du fichier
$CLUBSSIUploadTimeOutMinutes = 10

##################################################################
#Pour utiliser un proxy positionner à $True
$UseProxy = $True

#Infos du proxy
$PROXY           = "http://proxy.contoso.com:8080"
$PROXY           = "http://proxy-ght.chiva.local:8080"

#Si le Proxy gère l'authentification intégrée mettre à $True
$ProxyUseIntegratedAuthentForCurrentUser = $True

# Ne positionner que si ProxyUseIntegratedAuthentForCurrentUser est à $False
$PROXYUser       = ""
$PROXYPassword    = ""


##################################################################


function btoa {
    #Fonction traduite du javascript depuis le site club-ssi, convertion de binaire en ascii
    param (
        [string]$chaine
    )

    # Base64 Alphabet
    $alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    $output = ""
    $index = 0


    # Encodage par blocs de 4 octets
    while ($index -lt $chaine.Length) {
        
        [int]$char1 = (([char]$chaine[$index++]))# -shl 16)
        [int]$char2 = (([char]$chaine[$index++]))# -shl 8)
        [int]$char3 = (([char]$chaine[$index++]))# -shr 18)

        $combined = ($char1 -shl 16) -bor ($char2 -shl 8) -bor $char3

        $output += $alphabet[($combined -shr 18) -band 63]
        $output += $alphabet[($combined -shr 12) -band 63]
        $output += if ($index -le $chaine.Length + 1) { $alphabet[($combined -shr 6) -band 63] } else { "=" }
        $output += if ($index -le $chaine.Length) { $alphabet[$combined -band 63] } else { "=" }
    }
    $output

    return $output
}


Function getHeaders($user, $password) { #TODO enlever les paramètres pour l'ancien portail ANSSI
        #Nouvelle Version du portail
        $encodedCreds = btoa "$($CLUBSSI_SESSION_GUID):$($CLUBSSI_SESSION_UploadToken)"

        $Headers = @{
            Authorization = "Basic $encodedCreds"
        }

        return $Headers
}


Function BuildAndInvokeWebRequest($url, $useProxy, $proxy, $useDefaultcredential, $proxyuser, $proxyPassword, $basicAuthUser, $basicAuthPassword, $outFile) {
        
        #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        #v0.9.1 Si DC en 2012R2 forcer TLS1.2, Merci Tierry Agon CHIC CM, non activé par défaut ;)

        $command = "Invoke-WebRequest -Uri `$url -UseBasicParsing "
        #v0.9.1 -UseBasicParsing : permet de fonctionner Si la fonctionnalité IE a été supprimé, Merci Tierry Agon CHIC CM

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

Start-Transcript -Path "$($ORADADInstallPath)\OradadAutoGenerate.log"

Write-Output "#########################################"
Write-Output "Paramètres :"
Write-Output "UpdateORADAD      : $($UpdateORADAD)"
Write-Output "generateAndUpload : $($generateAndUpload)"
Write-Output "domain            : $($domain)"
Write-Output "#########################################"


if($UpdateORADAD) {

    #Récupération de la dernière version sur GitHub

    $repo = "ANSSI-FR/ORADAD"
    $file = "ORADAD.zip"

    $releases = "https://api.github.com/repos/$repo/releases"

    $response = BuildAndInvokeWebRequest -url $releases -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -proxyuser $PROXYUser -proxyPassword $PROXYPassword
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
        BuildAndInvokeWebRequest -url $download -outFile $zip -useProxy $UseProxy -proxy $PROXY -useDefaultcredential $ProxyUseIntegratedAuthentForCurrentUser -proxyuser $PROXYUser -proxyPassword $PROXYPassword
        
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
    #Si on ne mets pas à jour in utilise le $ORADADInstallPath comme chemin
    $pathORADAD = $ORADADInstallPath
}


if($generateAndUpload) {

    foreach($currentDom in $domain) {

        Write-Output "#########################################"
        Write-Output "Génération pour le domaine : $($currentDom)"
        Write-Output "#########################################"

        Write-Output "Lancement du process ORADAD: $($pathORADAD)\ORADAD.exe"
        if(Test-Path -Path "$($pathORADAD)\ORADAD.exe") {
            $processORADAD = Start-Process -FilePath "$pathORADAD\ORADAD.exe" -ArgumentList "--force" -WorkingDirectory $pathORADAD -PassThru -Wait
        } else {
            Write-Output "Erreur : $($pathORADAD)\ORADAD.exe n'est pas accessible"
            exit 1
        }

        #TODO vérifier les droits d'écriture pour le .mla
    
        if($processORADAD.ExitCode -ne 0) {
            Write-Output "Une erreur est intervenue dans ORADAD, exitCode: $($processORADAD.ExitCode)"
            exit 1
        }

    
        $lastMLAForDomain = Get-ChildItem -Path "$($pathORADAD)\$($currentDom)_*.mla" | sort LastWriteTime | select -last 1

        write-output "Fichier généré : $lastMLAForDomain"

        Write-Output "#########################################"
        Write-Output "Upload pour le domaine : $($currentDom)"
        Write-Output "#########################################"

        Try {
            Add-Type -AssemblyName 'System.Net.Http'

            $encodedCreds = btoa "$($CLUBSSI_SESSION_GUID):$($CLUBSSI_SESSION_UploadToken)"
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
            $datum = [math]::Floor((Get-Date -UFormat %s)/ 1e3)

            $client = New-Object System.Net.Http.HttpClient $httpClientHandler
            $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $encodedCreds);
            $client.DefaultRequestHeaders.Add("ZKBEID",$CLUBSSI_SESSION_GUID)
            $client.DefaultRequestHeaders.Add("datum",$datum)
            $client.DefaultRequestHeaders.Add("typeUpload",1) #.mla
            $client.Timeout = New-TimeSpan -Minutes $CLUBSSIUploadTimeOutMinutes

            $content = New-Object System.Net.Http.MultipartFormDataContent
            $fileStream = [System.IO.File]::OpenRead($lastMLAForDomain)
            $fileName = [System.IO.Path]::GetFileName($lastMLAForDomain)
            $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
            $content.Add($fileContent, $CLUBSSIFieldName, $fileName)
      

            #$result = $client.PostAsync($CLUBSSIUploadUrl, $content).Result
            $result.EnsureSuccessStatusCode()

            Out-File -FilePath "$lastMLAForDomain.isSend"
        }
        Catch {
    
            Write-Output "Erreur lors de l'upload vers $CLUBSSIUploadUrl pour $lastMLAForDomain"
            Write-Output $_
        }
        Finally {
            if ($client -ne $null) { $client.Dispose() }
            if ($content -ne $null) { $content.Dispose() }
            if ($fileStream -ne $null) { $fileStream.Dispose() }
            if ($fileContent -ne $null) { $fileContent.Dispose() }
        }
    } #Fin foreach domain
    
}

Stop-Transcript
