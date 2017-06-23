<#
.Synopsis
   Removes Splunk UniversalForwarder from host without windows installer assitance.
.DESCRIPTION
   For use only in cases where MSI package install/uninstall routines fail.  
.NOTES
   Use at your own risk as last resort.
#>

$OrigVerbosePreference = $VerbosePreference
$OrigDebugPreference = $DebugPreference
$VerbosePreference = "Continue"
$DebugPreference = "SilentlyContinue" 

########################################
### FUNCTIONS
########################################


function remove-installer-packagekeys {
    param ($ProductCode)
    
    if (!(test-path HKCR:)) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT }

    $Key = "HKCR:\Installer\Products\$($ProductCode)" 
    if (test-path $Key) {
        write-verbose "found installer key: $($Key), removing it."
        get-item $Key | Remove-Item -Recurse 
    }

    $Key = "HKCR:\Installer\Features\$($ProductCode)" 
    if (test-path $Key) { 
        write-verbose "found feature key: $($Key), removing it."
        get-item $Key | Remove-Item -Recurse 
    }

    $keys = Get-ChildItem "HKCR:\Installer\UpgradeCodes"
    foreach ($Key in $Keys) {
        if ($Key.Property -eq $ProductCode) {
            Write-verbose "found upgrade key $($Key), removing it."
            $Key | Remove-Item -Recurse
        }
    }
} # remove-regkey-hkcr

########################################
### MAIN
########################################

### IF SERVICE IS RUNNING, STOP IT
$ServiceName = "SplunkForwarder"
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($Service) { 
    Write-Verbose "$($ServiceName) service is running, stopping it."
    $Service | Stop-Service -Force 
}



### IF SERVICE IS REGISTERED, DELETE IT
$Service = Get-WmiObject -Class Win32_Service -Filter "Name='$($ServiceName)'"
if ($Service) { 
    Write-Verbose "$($ServiceName) service is present, deleting it."
    [void] $service.delete()
}


### IF INSTALLATION DIRECTORY IS PRESENT, REMOVE IT
$InstallDir = "C:\Program Files\SplunkUniversalForwarder"
if (Test-Path -Path $InstallDir)  { 
    Write-Verbose "Found $($InstallDir), removing it."
    Remove-Item -Path $InstallDir -Recurse 
}


### IF DRIVERS ARE PRESENT, REMOVE THEM
$SearchFor = "Splunk"
$results = @()
$keys = Get-ChildItem "HKLM:\System\CurrentControlSet\Services" 
foreach ($Key in $Keys) {
    $obj = New-Object psobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $Key.GetValue("DisplayName")
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Description -Value $Key.GetValue("Description")
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Path -Value $Key.PSPath
    $results += $obj
}
$results = $results | where {(($_.DisplayName -match $SearchFor) -or ($_.Description -match $SearchFor))}
foreach ($result in $results) {
    Write-Verbose "Found $($result.DisplayName) driver, removing."    
    $result | Remove-Item -Recurse
}


### IF UNINSTALL KEY IS PRESENT, REMOVE IT
$results = @()
$SearchFor = "UniversalForwarder"
$keys = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
foreach ($Key in $Keys) {
    $obj = New-Object psobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name GUID -Value $Key.pschildname
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $Key.GetValue("DisplayName")
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayVersion -Value $Key.GetValue("DisplayVersion")
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Path -Value $Key.PSPath
    $results += $obj
}
$results = $results | where {$_.DisplayName -match $SearchFor} 
foreach ($result in $results) {
    Write-Verbose "Found $($result.DisplayName) uninstall key, removing."    
    $result | Remove-Item -Recurse    
}


### IF PRODUCT KEY IS PRESENT, REMOVE IT
if (!(test-path HKCR:)) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT }
$results = @()
$SearchFor = "UniversalForwarder"
$keys = Get-ChildItem HKCR:\Installer\Products
foreach ($Key in $Keys) {
    $obj = New-Object psobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Name -Value $Key.PSChildName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name ProductName -Value $Key.GetValue("ProductName")
    $results += $obj
}
$results = $results | where {$_.ProductName -match $SearchFor} 
foreach ($result in $results) {
    $ProductCode = $Result.Name
    Write-Verbose "Found ProductCode $($ProductCode) for $($SearchFor) product, removing installer references."
    remove-installer-packagekeys -ProductCode $ProductCode
}


### SET LOGGING LEVELS BACK TO ORIGINAL STATE
$VerbosePreference = $OrigVerbosePreference
$DebugPreference = $OrigDebugPreference 