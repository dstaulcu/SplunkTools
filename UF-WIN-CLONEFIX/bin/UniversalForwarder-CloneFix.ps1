# Notes
# splunk must be stopped before clone-prep-clear-config
# splunk must be started via .\bin\splunk start process in order for config updates to take effect
# https://docs.splunk.com/Documentation/Splunk/8.0.2/Admin/Integrateauniversalforwarderontoasystemimage

<#
TO DO:
Presently, on condition of need to rename, machine goes into reboot loop.  Correct for that.
#>



# define variables for use throughout script
$computer_name = $env:COMPUTERNAME
$bln_needs_clone_prep = $false
$bln_needs_restart = $false
$splunk_home = "C:\Program Files\Splunk"
$splunk_conf_inputs = "$($splunk_home)\etc\system\local\inputs.conf"
$splunk_conf_server = "$($splunk_home)\etc\system\local\server.conf"
$splunk_conf_inputs_spec = "host"
$splunk_conf_server_spec = "serverName"

# if splunk.exe is not present we have bigger problems
$splunk_exe = "$($splunk_home)\bin\splunk.exe"
if (!(Test-Path -path $splunk_exe)) {
    write-host "Unable to find path to splunk.exe, quitting."
    Exit-PSHostProcess
}

# check to see that current computer name matches serverName spec value in server.conf
if (Test-Path -Path $splunk_conf_server) {
    $specvalue = Get-Content -Path $splunk_conf_server | Select-String -Pattern "^$($splunk_conf_server_spec)\s*="
    if ($specvalue) {    
        $specvalue = ($specvalue -split "=")[1].trim()
        if ($computer_name -ne $specvalue) {
            $bln_needs_clone_prep = $true
            $server_conf = ((Get-Content -Path $splunk_conf_server) -replace $specvalue,$computer_name)| Set-Content -Path $splunk_conf_server

            write-host "spec [$($splunk_conf_server_spec)] has value [$($specvalue)] NOT matching host name [$($computer_name)]."        
        }
    } else {
        # this condition is possible if measured before splunk.exe start command issued
        $bln_needs_restart = $true        
    }
}

# check to see that current computer name matches host spec value in server.conf
if (Test-Path -Path $splunk_conf_inputs) {
    $specvalue = Get-Content -Path $splunk_conf_inputs | Select-String -Pattern "^$($splunk_conf_inputs_spec)\s*="
    if ($specvalue) {    
        $specvalue = ($specvalue -split "=")[1].trim()
        if ($computer_name -ne $specvalue) {
            $bln_needs_clone_prep = $true
            $inputs_conf = ((Get-Content -Path $splunk_conf_inputs) -replace $specvalue,$computer_name)| Set-Content -Path $splunk_conf_inputs
            write-host "spec [$($splunk_conf_inputs_spec)] has value [$($specvalue)] NOT matching host name [$($computer_name)]."        
        }
    } else {
        # this condition is possible if measured before splunk.exe start command issued
        $bln_needs_restart = $true        
    }
}



# do clone prep if any of the previous checks inidicate need to do so
if ($bln_needs_clone_prep -eq $true) {
     Invoke-Command -ScriptBlock {Restart-Service splunkd -Force} 
}
# do restart if any of the previous checks inidicate need to do so

if ($bln_needs_restart -eq $true) {
    write-host "splunk restart needed... restarting now" 
    Invoke-Command -ScriptBlock { Start-Process -FilePath "C:\Program Files\Splunk\bin\splunk.exe" -ArgumentList "restart" -Wait -WindowStyle Hidden } 
    write-host "splunk restart completed"
}

