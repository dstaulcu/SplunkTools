
<#
https://docs.splunk.com/Documentation/Splunk/8.0.4/Admin/Deploymentclientconf
clientName = deploymentClient
* A name the deployment server can filter on
* Takes precedence over DNS names
* Default: deploymentClient
#>

#Get ComputerSystem class for access to Name, Manufacturer, Model, Domain, etc. properties
$ComputerSystem = Get-CimInstance -ClassName "CIM_ComputerSystem"

#Get OperatingSystem class for Name and version properties
$OperatingSystem = Get-CimInstance -ClassName "Win32_OperatingSystem"
switch ($OperatingSystem.ProductType)
{
    '1' { $OperatingSystemProductType = "Workstation" }
    '2' { $OperatingSystemProductType = "Domain Controller" }
    '3' { $OperatingSystemProductType = "Server" }
    Default {'Unknown'}
}

# Discovery system roles through presence of registered performance monitoring objects
function get-systemroles {

    $Roles = @()
    $CounterSetName = (Get-Counter -ListSet *).CounterSetName

    <#
    Print Server
    https://systemcenter.wiki/?GetCategory=Windows+Server+Print+Server
    #>
    if ($CounterSetName -match "^Print Queue$") {
        $Roles+="Print"    
    }

    <#
    DFS Server
    #>
    if ($CounterSetName -match "^DFS Replication Connections$") {
        $Roles+="DFS"    
    }

    <#
    Exchange Server
    https://systemcenter.wiki/?GetCategory=Exchange+Server+2013
    #>
    if ($CounterSetName -match "^Exchange Mailbox Database$") {
        $Roles+="Exchange"    
    }

    <#
    SharePoint Server
    https://systemcenter.wiki/?GetCategory=SharePoint+Server+2019
    #>
    if ($CounterSetName -match "^SharePoint Foundation$") {
        $Roles+="SharePoint"    
    }

    <#
    SQL Server
    https://systemcenter.wiki/?GetCategory=SQL+Server
    #>
    if ($CounterSetName -match "^SQL DB Engine:SQL Statistics$") {
        $Roles+="SQL"    
    }

    <#
    Active Directory Server
    https://systemcenter.wiki/?GetCategory=Windows+Server+Active+Directory+%28AD%29
    #>
    if ($CounterSetName -match "^AD Storage$") {
        $Roles+="AD"    
    }

    <#
    DHCP Server
    https://systemcenter.wiki/?GetCategory=Windows+Server+DHCP
    #>
    if ($CounterSetName -match "^DHCP Server$") {
        $Roles+="DHCP"    
    }

    <#
    DNS Server
    https://systemcenter.wiki/?GetCategory=Windows+Server+DNS
    #>
    if ($CounterSetName -match "^DNS$") {
        $Roles+="DNS"    
    }

    <#
    Hyper-V Server
    https://systemcenter.wiki/?GetCategory=Windows+Server+Hyper-V
    #>
    if ($CounterSetName -match "^Hyper-V Virtual Switch$") {
        $Roles+="Hyper-v"    
    }

    [string]$Roles = $Roles -join ","
    return($Roles)
    
}
$Roles = get-systemroles

$Discovery = [ordered]@{
    Name = $ComputerSystem.Name
    Manufacturer = $ComputerSystem.Manufacturer
    Model = $ComputerSystem.Model
    Domain = $ComputerSystem.Domain
    OSType = $OperatingSystemProductType
    OSVersion = $OperatingSystem.Version
    Roles = $Roles
}

# convert has to single line of key-value pairs.
$DiscoveryString = ($Discovery.GetEnumerator() | % { "$($_.Key)=$($_.Value)" }) -join ';'
$DiscoveryString = $DiscoveryString -replace "=","@"

# check whether any changes to clientName in deploymentclient.conf are needed
# define variables for use throughout script
$bln_needs_restart = $false
$splunk_home = "C:\Program Files\SplunkUniversalForwarder"
$splunk_conf_deploymentclient = "$($splunk_home)\etc\system\local\deploymentclient.conf"

# if splunk.exe is not present we have bigger problems
$splunk_exe = "$($splunk_home)\bin\splunk.exe"
if (!(Test-Path -path $splunk_exe)) {
    write-host "Unable to find path to splunk.exe, quitting."
    Exit-PSHostProcess
}

# if deploymentclient file exists
if (Test-Path -Path $splunk_conf_deploymentclient) {

    # get the content of the file
    $deploymentclient = Get-Content -path $splunk_conf_deploymentclient

    # create the clientName spec if it does not exist
    if (!($deploymentclient | select-string -pattern "^clientName")) {      
        write-host "client name spec not found, creating one"
        $deploymentclient = $deploymentclient -replace "\[deployment-client\]","[deployment-client]`r`nclientName = $($env:computername)"
    }

    # update the spec file if it does not have an exact match to new tags
    if (!($deploymentclient | select-string -pattern "^clientName = $($DiscoveryString)")) {      
        write-host "client name spec value is not an exact match, replacing"
        $deploymentclient = $deploymentclient -ireplace "clientName = .*","clientName = $($DiscoveryString)"
        if (Test-Path -Path $splunk_conf_deploymentclient) { Remove-Item -Path $splunk_conf_deploymentclient -Force }
        Set-Content -Path $splunk_conf_deploymentclient -Value $deploymentclient
        $bln_needs_restart = $true
    }

}

if ($bln_needs_restart -eq $true) {
    write-host "splunk restart needed... restarting now" 
    Invoke-Command -ScriptBlock { Start-Process -FilePath $splunk_exe -ArgumentList "restart" -Wait -WindowStyle Hidden } 
    write-host "splunk restart completed"
}


# do restart if any of the previous checks inidicate need to do so
if ($bln_needs_restart -eq $true) { 
    Invoke-Command -ScriptBlock { Restart-Service SplunkForwarder -Force } 

}