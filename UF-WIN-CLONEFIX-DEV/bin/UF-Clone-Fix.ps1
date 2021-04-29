$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$LogFile = "$($SplunkHome)\var\log\splunk\uf-clone-fix.log"
$SplunkExe = "$($SplunkHome)\bin\splunk.exe"

$DebugPreference = "Continue"

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
    Add-Content -Path $LogFilePath -Value $message
}

# make sure splunk home exists
if (-not(Test-Path -Path $SplunkExe)) {
    write-logfile -LogFilePath $LogFile -Level INFO -message "Path to Splunk binary [$($SplunkExe)] not found. Exiting."
    exit
}

# do the clone prep
write-logfile -LogFilePath $LogFile -Level INFO -message "stopping splunk"
Start-Process -FilePath $SplunkExe -ArgumentList "stop" -Wait -WindowStyle Hidden
$status = (Get-Service SplunkForwarder).Status
write-logfile -LogFilePath $LogFile -Level INFO -message "splunk service status is [$($status)]."

write-logfile -LogFilePath $LogFile -Level INFO -message "clearing splunk config"
Start-Process -FilePath $SplunkExe -ArgumentList "clone-prep-clear-config" -Wait -WindowStyle Hidden

$status = Test-Path -Path "$($SplunkHome)\cloneprep"
write-logfile -LogFilePath $LogFile -Level INFO -message "clone prep file status [$($status)]."

write-logfile -LogFilePath $LogFile -Level INFO -message "restarting splunk"
Start-Process -FilePath $SplunkExe -ArgumentList "start" -Wait -WindowStyle Hidden

$status = (Get-Service SplunkForwarder).Status
write-logfile -LogFilePath $LogFile -Level INFO -message "splunk service status is [$($status)]."
$status = Test-Path -Path "$($SplunkHome)\cloneprep"
write-logfile -LogFilePath $LogFile -Level INFO -message "clone prep file status [$($status)]."
