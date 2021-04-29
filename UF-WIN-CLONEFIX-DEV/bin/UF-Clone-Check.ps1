##############################################################################
# VARIABLES
##############################################################################

$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$SplunkExe = "$($SplunkHome)\bin\splunk.exe"
$LogFile = "$($SplunkHome)\var\log\splunk\uf-clone-fix.log"
$InputsLocal = "$($SplunkHome)\etc\system\local\inputs.conf"
$ServerLocal = "$($SplunkHome)\etc\system\local\server.conf"
$HostName = [system.net.dns]::getHostName()
$bRestartNeeded = $false
$bClonePrepNeeded = $false

##############################################################################
# FUNCTIONS
##############################################################################

function write-logfile {
    param($LogFilePath
    ,[ValidateSet("ERROR","WARNING","INFO","DEBUG")]
     $Level
    ,$message)

    # get date in splunk string format
    $inputDate=(Get-Date)
    $inputDateString = $inputDate.ToString('MM-dd-yyyy HH:mm:ss.fff zzzz')
    $inputDateParts = $inputDateString -split " "
    $inputDateZone = $inputDateParts[2] -replace ":",""
    $outputDateString = "$($inputDateParts[0]) $($inputDateParts[1]) $($inputDateZone)"

    # prepare message
    $Message = "$($outputDateString)`t$($Level)`tMessage=`"$($Message)`""

    # print message to console
    Write-Host $message

    # write message to file
    # Add-Content -Path $LogFilePath -Value $message
}

##############################################################################
# MAIN
##############################################################################

# make sure splunk home exists
if (-not(Test-Path -Path $SplunkExe)) {
    write-logfile -LogFilePath $LogFile -Level INFO -message "Path to Splunk binary [$($SplunkExe)] not found. Exiting. "
    exit
}

# get splunk version
$SplunkVersion = [version]((Get-Item -Path $SplunkExe).VersionInfo).FileVersion

# if splunk version is greater than 8.1 and local inputs.conf exist than delete it
if ($SplunkVersion -ge "8.1") {
    if (Test-Path -Path $InputsLocal) { 
        write-logfile -LogFilePath $LogFile -Level INFO -message "Version of Splunk [$($SplunkVersion)] is GE 8.1 and local inputs.conf is present. Deleting file."
        Remove-Item -Path $InputsLocal -Force 
        $bRestartNeeded = $true
    }
}

# if local inputs.conf exists and host spec is not expected value then clone prep
if (Test-Path -Path $InputsLocal) {
    $match = Get-Content -Path $InputsLocal | Select-String -Pattern "^host\s+=\s*(.*)"
    if ($match) {
        $specvalue = $match.Matches.Groups[1].Value
        $pattern = "^$($HostName)$"
        if ($specvalue -notmatch $pattern) {
            write-logfile -LogFilePath $LogFile -Level INFO -message "Local inputs [host] value [$($specvalue)] does not match [$($pattern)]. Clone prep is needed."
            $bClonePrepNeeded = $true
            $bRestartNeeded = $true
        }
    } 
}

# if local inputs.conf exists and host spec is not expected value then clone prep
if (Test-Path -Path $ServerLocal) {
    $match = Get-Content -Path $ServerLocal | Select-String -Pattern "^serverName\s+=\s*(.*)"
    if ($match) {
        $specvalue = $match.Matches.Groups[1].Value
        $pattern = "^$($HostName)$"
        if ($specvalue -notmatch $pattern) {
            write-logfile -LogFilePath $LogFile -Level INFO -message "Local server [serverName] value [$($specvalue)] does not match [$($pattern)]. Clone prep is needed."
            $bClonePrepNeeded = $true
            $bRestartNeeded = $true
        }
    } 
}

if ($bClonePrepNeeded -eq $true) {
    write-logfile -LogFilePath $LogFile -Level INFO -message "invoking clone fix"
	$Result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "powershell.exe -file `"C:\Program Files\SplunkUniversalForwarder\etc\apps\UF-WIN-CLONEFIX-DEV\bin\UF-Clone-Fix.ps1`""	
} else {
    if ($bRestartNeeded -eq $true) {
        write-logfile -LogFilePath $LogFile -Level INFO -message "performing restart without clone prep"
        $Result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "powershell.exe Restart-Service -Name SplunkForwarder"
    } else {
        write-logfile -LogFilePath $LogFile -Level INFO -message "no changes needed"
    }
}







