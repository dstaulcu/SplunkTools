function splunk-spec-disable {
    param($file,$spec)
    if (Test-Path -Path $file) {
        $content = Get-Content -Path $file
        Remove-Item -Path $file -Force
        foreach ($line in $content) {
            if ($line -match $spec) {
                $line = "#$($line)"
            }
            Add-Content -Path $file -Value $line 
        }
    }
}

function splunk-spec-enable {
    param($file,$spec)
    if (Test-Path -Path $file) {
        $content = Get-Content -Path $file
        Remove-Item -Path $file -Force
        foreach ($line in $content) {
            if ($line -match $spec) {
                $line = $line -replace "#",""
            }
            Add-Content -Path $file -Value $line 
        }
    }
}


$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$Splunk = "$($SplunkHome)\bin\splunk.exe"
$Spec = "phoneHomeIntervalInSecs"
if (!(Test-Path -Path $Splunk)) {
    write-host "File not found: $($Splunk). Exiting."
    exit
}
$dcsettings = & $Splunk cmd btool deploymentclient list --debug
if ($dcsettings -match $Spec) {
    $thematch = $dcsettings -match $Spec
    $theconf = $thematch -replace "(\s+$($Spec) = \d+)",""
    splunk-spec-disable -file $theconf -spec $Spec

    write-host "Commented $($spec) in $($theconf). Restarting Splunk"
    & $splunk restart

    $threadwait = 30 # number of seconds for splunk to wait to read in commented spec after restart
    $counter = 0
    do
    {
        sleep -Seconds 1
        $counter++
        $remaining = $threadwait - $counter
        Write-Progress -SecondsRemaining $remaining -Activity "Giving splunk time to read in new spec"
         
    }
    until ($counter -gt $threadwait)
    splunk-spec-enable -file $theconf -spec $Spec
    write-host "Uncommented $($spec) in $($theconf). Have a great day!"

} else {
    write-host "$($spec)is not defined. Nothing to do!"    
}
