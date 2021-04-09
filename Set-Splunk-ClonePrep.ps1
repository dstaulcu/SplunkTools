$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$SplunkLogs = "$($SplunkHome)\var\log\splunk"
$SplunkApps = "$($SplunkHome)\etc\apps"


<#

https://docs.splunk.com/Documentation/Forwarder/8.1.3/Forwarder/Makeauniversalforwarderpartofahostimage

Make a universal forwarder part of a host image
You can deploy a universal forwarder as part of a host image or virtual machine. This is particularly useful if you have a large number of universal forwarders to deploy. If you have just a few, you might find it simpler to install them manually, as described for Windows and nix hosts.

Steps to deployment
Once you have downloaded the universal forwarder and have planned your deployment, perform these steps:

1. Install the universal forwarder on a test machine.
2. Perform any post-installation configuration.
3. Test and tune the deployment.
4. Install the universal forwarder with the tested configuration onto a source machine.
5. Stop the universal forwarder.
6. Run this CLI command on the forwarder:
./splunk clone-prep-clear-config
This clears instance-specific information, such as the server name and GUID, from the forwarder. This information will then be configured on each cloned forwarder at initial start-up.
7. Prepare your image or virtual machine, as necessary, for cloning.
8. On *nix systems, set the splunkd daemon to start on boot using cron or your scheduling system of choice. On Windows, set the service to Automatic but do not start it.
9. Distribute the system image or virtual machine clones to machines across your environment and start them.
10. Confirm that forwarders have connected to the indexers you specified during forwarder setup.

#>

write-host "Confirming this powershell session is running with admin privledges..."
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-host "Insufficient permissions to run this script. Open the PowerShell console as an administrator and run this script again."
    exit
}

write-host "Stopping the splunk universal forwarder service..."
Start-Process -FilePath "$($SplunkHome)\bin\splunk.exe" -ArgumentList "stop" -WindowStyle Hidden -Wait

write-host "Running the splunk universal forwarder clone-prep-clear-config commmand..."
Start-Process -FilePath "$($SplunkHome)\bin\splunk.exe" -ArgumentList "clone-prep-clear-config" -WindowStyle Hidden

write-host "Removing the splunk universal forwarder internal log files..."
if (Test-Path -Path $SplunkLogs) {
    get-childitem -path $SplunkLogs -Filter "*.log" | ?{$_.Length -gt 0} | Remove-Item -Force
}

write-host "Removing any splunk universal forwarder apps previously downloaded..."
if (Test-Path -Path $SplunkApps) {
    Get-ChildItem -Path $SplunkApps | ?{$_.name -notmatch "(introspection_generator_addon|learned|search|SplunkUniversalForwarder|splunk_httpinput|splunk_internal_metrics)"} | Remove-Item -Recurse -Force
}

write-host "Removing splunk universal forwarder inputs.conf file if exists..."
$localInputsFile = "$($SplunkHome)\etc\system\local"
if (Test-Path -Path $localInputsFile) {
    Get-ChildItem -Path $localInputsFile | Remove-Item -Recurse -Force
}

write-host "Clearing windows EventLogs so we don't forward duplicate events from base image..."
$EventLogs = Get-WinEvent -ListLog * | ?{$_.RecordCount -gt 0}
foreach ($EventLog in $EventLogs) {
    try {
        (New-Object System.Diagnostics.Eventing.Reader.EventLogSession).ClearLog($EventLog.LogName)
    } catch {}
}

write-host "All set!"

<#

# Various commands helpful for troubleshooting

# show values of concern in pertinent config files
& "$($SplunkHome)\bin\splunk.exe" cmd btool server list --debug | Select-String -Pattern "(^|\s)serverName\s+?=" 
& "$($SplunkHome)\bin\splunk.exe" cmd btool deploymentclient list --debug | Select-String -Pattern "(^|\s)clientName\s+?="
& "$($SplunkHome)\bin\splunk.exe" cmd btool inputs list --debug | Select-String -Pattern "(^|\s)host\s+?="

# restart the process
Start-Process -FilePath "$($SplunkHome)\bin\splunk.exe" -ArgumentList "restart" -WindowStyle Hidden -Wait

# show resultant deploymentclient configuration
& "$($SplunkHome)\bin\splunk.exe" cmd btool deploymentclient list --debug

# check to see which of any apps were downloaded
get-childitem -path "$($SplunkHome)\etc\apps"

# print internal logs of type warning or error
get-content -path "$($SplunkHome)\var\log\splunk\splunkd.log" | select-string -pattern "\s(WARN|ERROR)\s" 

# watch the internal log
get-content -path "$($SplunkHome)\var\log\splunk\splunkd.log" -last 50 -wait


#>

