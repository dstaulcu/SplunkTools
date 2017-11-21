
$SplunkHome = 'C:\Program Files\SplunkUniversalForwarder'
$mismatch = $false

# check server.conf files
$serverList = & $SplunkHome\bin\splunk.exe cmd btool server list
$entries = $serverList -match "^serverName\s*="
foreach ($entry in $entries) {
    $entrydata = $entry.split("=")[1].Trim()
    if (($entrydata -ne $env:COMPUTERNAME) -and ($entrydata -ne "`$COMPUTERNAME")) {
        write-verbose "Value mismatch in a server.conf file. [$($entry) -ne $($env:computername)]"
        $mismatch = $true
    }
}

# check inputs.conf files
$inputsList = & $SplunkHome\bin\splunk.exe cmd btool inputs list
$entries = $inputsList -match "^host\s*="
foreach ($entry in $entries) {
    $entrydata = $entry.split("=")[1].Trim()
    if (($entrydata -ne $env:COMPUTERNAME) -and ($entrydata -ne "`$decideOnStartup")) {
        write-verbose "Value mismatch in an inputs.conf file. [$($entry) -ne $($env:computername)]"
        $mismatch = $true
    }
}

# if a mismatch was detected, stop splunk, clear-config, restart splunk
if ($mismatch) {
    write-host "one or mismatches detected, personalizing splunk agent."
    Get-Service SplunkForwarder | Stop-Service 
    & "$($SplunkHome)\bin\splunk.exe" clone-prep-clear-config
    Get-Service SplunkForwarder | Start-Service
}
