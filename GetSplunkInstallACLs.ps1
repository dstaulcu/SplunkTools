$SplunkInstallDir = "C:\Program Files\SplunkUniversalForwarder"

# get the version of Splunk
$SplunkReadmeFile = Get-ChildItem -Path $SplunkInstallDir -Filter *README*.txt
$SplunkVersion = $SplunkReadmeFile | Get-Content | select-string -Pattern "^Splunk \d+"


$DataSet = @()

$folders = Get-ChildItem -Path $SplunkInstallDir -Directory -Recurse

foreach ($folder in $folders) {


    $ACL = Get-Acl -Path $folder.FullName 

    foreach ($ACE in $ACL.Access) {


        if (($ACE.IdentityReference -match "(Everyone|Users)") -and ($ACE.FileSystemRights -notmatch "\d+")) {

#            write-host $folder.fullname
#            write-host $ACE.IdentityReference

            $info = @{
                "SplunkVersion" = $SplunkVersion
                "FolderName" = $folder.FullName
                "IdentityReference" = $ACE.IdentityReference
                "FileSystemRights" = $ACE.FileSystemRights
            }

            $DataSet += New-Object -TypeName PSObject -Property $info

        }


    }

}

$SplunkVersion = $SplunkVersion -replace " ","_"
$DataSet | Export-Csv -Path "C:\Development\ACLList_$($SplunkVersion).txt" -NoTypeInformation
$Dataset | Out-GridView



Get-ChildItem -Path C:\Development -Filter ACLList*.txt


