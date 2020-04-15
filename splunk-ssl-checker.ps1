<#
Splunk Universal Forwarder SSL Certificate Checker for Windows
A powershell-based version of https://splunkbase.splunk.com/app/3172/#/details
Designed to run as a scripted input
#>

$splunkDir = 'C:\Program Files\SplunkUniversalForwarder'
if (!(Test-Path -Path $splunkDir)) {
    write-host "Splunk installation directory not found.  Exiting."
    exit
}

# define list of splunk conf file names known to control certificate behavior
$include_files = @("*deploymentclient.conf","*inputs.conf","*outputs.conf","*server.conf","*web.conf")
# define list of splunk specification names known to include certificate paths
$specs = @("caCertFile","serverCert","caPath","sslRootCAPath","rootCA","sslKeysfile","clientCert","sslCertPath","caCertPath")

# get list of files matching type and name of interest
$files = Get-ChildItem -Path $splunkDir -Recurse -Include $include_files -Filter "*.conf"

# step through each file
foreach ($file in $files) {
    # get the content of file into array of lines
    $content = Get-Content -Path $file.fullname
    foreach ($line in $content) {
        # check to see if any of the specs we care about are at beginning of current line
        foreach ($spec in $specs) {
            if ($line -match "^$($spec)") {
                # isolate the value for the spec (path to certificate)
                $SpecValue = (($line -split "=")[1]).trim()
                # expand splunk home environment variable in path
                $SpecValueEx = $SpecValue -replace '\$SPLUNK_HOME',$splunkDir
                # check to path is a certificate we can access
                if (Test-Path -Path $SpecValueEx -PathType Leaf) {
                    # use .Net method to read certificate for typed-output instead of shelling to openssl
                    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 $SpecValueEx
                    # calculate number of days until certificate expires
                    $daysToExpire = (New-TimeSpan -end $($cert.NotAfter)).Days
                    # if certificate expires in less than 60 days, make a note of it
                    if ($daysToExpireStatus -le 60) { $daysToExpireStatus = "WARN" } else { $daysToExpireStatus = "OK" }
                    # prepare a string of key-value pairs for splunk to extract nicely
                    $Message = "confName=`"$($file.name)`""
                    $Message += ", specName=`"$($spec)`""
                    $Message += ", cert=`"$($SpecValue)`""
                    $Message += ", expires=`"$($cert.NotAfter)`""
                    $Message += ", daysToExpire=`"$($daysToExpire)`""
                    $Message += ", daysToExpireStatus=`"$($daysToExpireStatus)`""                   
                    $Message += ", Issuer=`"$($cert.Issuer)`""
                    $Message += ", Subject=`"$($cert.Subject)`""
                    $Message += ", Version=`"$($cert.Version)`""
                    $Message += ", confPath=`"$($file.FullName)`""                
                    # print output for input of splunk script-based input handler to catch
                    write-output $Message
                }
            }            
        }
    }
}
