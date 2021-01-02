
<#
$DebugPreference = "Continue"           # Debug Mode
$DebugPreference = "SilentlyContinue"   # Normal Mode
#>

$TestDurationTotalSeconds = 120
$SysinternalsSuitePath = "C:\Users\Administrator\Downloads\SysinternalsSuite"
$LogFile = "C:\ProgramData\SysmonBetaTest\activity.log"
$ConstrainSysmonCollection = $True

# creates Sysmon config with all inputs except specified type
function make-sysmon-config ($sysmonPath, $name) 
{

    Write-Debug "creating sysmon config"

    # Get sysmon schema into xml
    $sysmonSchemaPrint = & $sysmonPath -s 2> $null | Select-String -Pattern "<"
    $sysmonSchemaPrintXml = [xml]$sysmonSchemaPrint

    # spit out a new template file
    $events = $sysmonSchemaPrintXml.manifest.events.event | Where-Object {$_.name -notmatch "(SYSMON_ERROR|SYSMON_SERVICE_STATE_CHANGE|SYSMON_SERVICE_CONFIGURATION_CHANGE)"}

    $xmlConfig = @()
    $xmlConfig += "<Sysmon schemaversion=`"$($sysmonSchemaPrintXml.manifest.schemaversion)`">"
    if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "HashAlgorithms") { $xmlConfig += "`t<HashAlgorithms>*</HashAlgorithms>" }
    if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "CheckRevocation") { $xmlConfig += "`t<CheckRevocation/>" }
#    if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "DnsLookup") { $xmlConfig += "`t<DnsLookup>False</DnsLookup>" }
#    if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "ArchiveDirectory") { $xmlConfig += "`t<ArchiveDirectory/>" }
    $xmlConfig += "`t<EventFiltering>"


    foreach ($event in $events) {

        $printConfig = $true
        # print the section hearder listing ID (value), Description (template), and config file section id (rulename)
        $xmlConfig += ""
        $xmlConfig += "`t`t<!--SYSMON EVENT ID $($event.value) : $($event.template) [$($event.rulename)]-->"

        # print the section hearder data elements of event
        $items = ""
        foreach ($item in $event.data | Select Name) {
            if ($items -eq "") {
                $items = "$($item.name)"
            } else {
                $items += ", $($item.name)"
            }        
        }
        $xmlConfig += "`t`t<!--DATA: $($items)-->"

        #
        if ($event.value -match "12|13|17|19|20") { $printConfig = $false}

        if ($name -match "SYSMON_REG_KEY|SYSMON_REG_SETVALUE" -and $event) {
            $name = "SYSMON_REG_NAME"
        }

        if ($name -match "SYSMON_CREATE_NAMEDPIPE|SYSMON_CONNECT_NAMEDPIPE" -and $event) {
            $name = "SYSMON_CONNECT_NAMEDPIPE"
        }

        if ($name -match "SYSMON_WMI_FILTER|SYSMON_WMI_CONSUMER|SYSMON_WMI_BINDING" -and $event) {
            $name = "SYSMON_WMI_BINDING"
        }

        $matchtype = "include"
        if ($event.name -ieq $name) { 
            Write-Debug "setting $($event.name) match level to exclude"
            $matchtype = "exclude" 
        }
        

        if ($printConfig -eq $true) {
            $xmlConfig += ""
            $xmlConfig += "`t`t<RuleGroup name=`"`" groupRelation=`"or`">"
            $xmlConfig += "`t`t`t<$($event.rulename) onmatch=`"$($matchtype)`">"
            $xmlConfig += "`t`t`t</$($event.rulename)>"
            $xmlConfig += "`t`t</RuleGroup>"
        }
    }
    $xmlConfig += ""
    $xmlConfig += "`t</EventFiltering>"
    $xmlConfig += ""
    $xmlConfig += "</Sysmon>"

    $ConfigFile = "$($env:TEMP)\$($name).xml"
    if (Test-Path -Path $ConfigFile) { Remove-Item -Path $ConfigFile -Force }
    write-debug "writing config to file: $($configfile)"
    Set-Content -Path $ConfigFile -Value $xmlConfig

    return $ConfigFile

}

# merges new config, starts-sysmon
function reset-sysmon ($sysmonPath, $configpath)
{
    Write-Debug "configuring sysmon"
    Start-Process -FilePath $sysmonPath -ArgumentList @("-c --") -NoNewWindow
    Start-Sleep -Seconds 1
    Start-Process -FilePath $sysmonPath -ArgumentList @("-c",$configpath) -NoNewWindow
    Start-Sleep -Seconds 1
}

function format-splunktime {
    param (
        [parameter(Mandatory=$false)][datetime]$inputDate=(Get-Date)
    )

    $inputDateString = $inputDate.ToString('MM-dd-yyyy HH:mm:ss.fff zzzz')
    $inputDateParts = $inputDateString -split " "
    $inputDateZone = $inputDateParts[2] -replace ":",""
    $outputDateString  = "$($inputDateParts[0]) $($inputDateParts[1]) $($inputDateZone)"
    return $outputDateString
}

# gets event logs of specified type
function get-eventlog ($logname) 
{
    $events = Get-WInEvent -log $logname
    # Parse out the event message data            
    ForEach ($Event in $Events) {            
        # Convert the event to XML            
        $eventXML = [xml]$Event.ToXml()            
        # Iterate through each one of the XML message properties            
        For ($i=0; $i -lt $eventXML.Event.EventData.Data.Count; $i++) {            
            # Append these as object properties            
            Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  $eventXML.Event.EventData.Data[$i].name -Value $eventXML.Event.EventData.Data[$i].'#text'            
        }            
    }       
    return $Events
}

# Establish path to Sysmon
$sysmonPath = "$($env:windir)\sysmon.exe"
if (!(Test-Path -Path $sysmonPath)) {
    write-host "Sysmon.exe not present in $($sysmonPath). Exiting."
    exit
} 


# Ensure PowerSploit is present
$ModulePath = "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PowerSploit"

<#

# Make sure .NET 2.0 is present
if ((get-WindowsOptionalFeature -FeatureName "NetFX3" -Online).State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName "NetFX3" -All
}

#Disable AV
if ((Get-MpPreference).DisableRealtimeMonitoring -eq $false) {
    Read-Host -Prompt "Please disable A/V and press ENTER to continue.."
}

$url = "https://github.com/PowerShellMafia/PowerSploit/archive/master.zip"
$download = "$($env:temp)\master.zip"
if (Test-Path -Path $download) { Remove-Item -Path $download -Force -Recurse }
write-host "-downloading latest project from $($url)."
$Response = Invoke-WebRequest -Uri $url -OutFile $download

# extract the compressed content (if local copy older than 20 hours)
write-host "-extracting archive."
$extracted = "$($env:temp)\extracted"
if (Test-Path -Path $extracted) { Remove-Item -Path $extracted -Force -Recurse }
Expand-Archive -LiteralPath $download -DestinationPath $extracted -Force

# copy the module
Rename-Item -Path "$($extracted)\PowerSploit-master" -NewName "PowerSploit"
Copy-Item -Path "$($extracted)\PowerSploit" -Destination $ModulePath -Recurse -Force

#Disable AV
if ((Get-MpPreference).DisableRealtimeMonitoring -eq $false) {
    Read-Host -Prompt "Please disable A/V and press ENTER to continue.."
}

#Set PowerShell ExecutionPolicy is top allow execution of PowerSploit
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force

#>

# remove any marks of the web/streams
Get-ChildItem -path $ModulePath -Recurse | Unblock-File

$x = 0
do
{
    ################################################################################
    # SYSMON_CREATE_PROCESS: EventCode=1 RuleName=ProcessCreate
    ################################################################################
    $TestName = "SYSMON_CREATE_PROCESS"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $Process = start-process -FilePath "notepad.exe" -WindowStyle Hidden -PassThru
        Stop-Process -Id $Process.Id -ErrorAction stop            
        ###########################################################################    

    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_FILE_TIME: EventCode=2 RuleName=FileCreateTime
    ################################################################################
    $TestName = "SYSMON_FILE_TIME"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $TemporaryFile = New-TemporaryFile
        (Get-Item -path $TemporaryFile.FullName).CreationTime=("08 March 2016 18:00:00")
        Remove-Item -Path $TemporaryFile.FullName
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_NETWORK_CONNECT: EventCode=3 RuleName=NetworkConnect
    ################################################################################
    $TestName = "SYSMON_NETWORK_CONNECT"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $blah = Invoke-WebRequest -Uri "192.168.1.1" -DisableKeepAlive -UseBasicParsing
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_PROCESS_TERMINATE: EventCode=5 RuleName=ProcessTerminate
    ################################################################################
    $TestName = "SYSMON_PROCESS_TERMINATE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $Process = start-process -FilePath "notepad.exe" -WindowStyle Hidden -PassThru
        Stop-Process -Id $Process.Id -ErrorAction stop           
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2
    

    ################################################################################
    # SYSMON_DRIVER_LOAD: EventCode=6 RuleName=DriverLoad
    ################################################################################
    $TestName = "SYSMON_DRIVER_LOAD"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $ProcessPath = "$($SysinternalsSuitePath)\notmyfault64.exe"
        $Process = start-process -FilePath $ProcessPath -ArgumentList @("/AcceptEula") -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 1
        Stop-Process -Id $Process.Id -ErrorAction stop -Force  
        Get-Service myfault | Stop-Service
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_IMAGE_LOAD: EventCode=7 RuleName=ImageLoad
    ################################################################################
    $TestName = "SYSMON_IMAGE_LOAD"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $ProcessPath = "c:\windows\notepad.exe"
        $Process = start-process -FilePath $ProcessPath -WindowStyle Hidden -PassThru
        Stop-Process -Id $Process.Id -ErrorAction stop 
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_CREATE_REMOTE_THREAD: EventCode=8 RuleName=CreateRemoteThread
    ################################################################################
    # The CreateRemoteThread event detects when a process creates a thread in 
    # another process. This technique is used by malware to inject code and hide 
    # in other processes. The event indicates the source and target process. It 
    # gives information on the code that will be run in the new thread: 
    # StartAddress, StartModule and StartFunction. Note that StartModule and 
    # StartFunction fields are inferred, they might be empty if the starting 
    # address is outside loaded modules or known exported functions.
    ################################################################################
    $TestName = "SYSMON_CREATE_REMOTE_THREAD"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $ScriptPath = "$($env:temp)\$($TestName).ps1"
        if (Test-Path -Path $ScriptPath) { Remove-Item -Path $ScriptPath -Force }
        $Content = @()
        $Content += "param([string]`$processid,[string]`$dll)"
        $Content += "Import-Module PowerSploit"   
        $Content += "if (Get-Process | ?{`$_.id -eq `$processid}) {"
        $Content += "   write-host `"Process id `$(`$processid)`" exists"
        $Content += "   if (Test-Path -Path `$dll) {"
        $Content += "      write-host `"file `$(`$dll)`" exists"
        $Content += "      Invoke-DllInjection -ProcessID `$processid -Dll `$dll"
        $Content += "   }"
        $Content += "}"
        Set-Content -PassThru $ScriptPath -Value $Content | Out-Null

        $dll = "C:\Windows\System32\advapi32.dll"
        $ProcessPath = "c:\windows\notepad.exe"

        $Process = start-process -FilePath $ProcessPath -WindowStyle Hidden -PassThru
        Start-Process -FilePath "Powershell.exe" -ArgumentList @("-version 2.0","-file $($ScriptPath)","-processid $($process.id)","-dll $($dll)") -Wait -WindowStyle Hidden
        Stop-Process -Id $process.id -Force
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_RAWACCESS_READ: EventCode=9 RuleName=RawAccessRead
    ################################################################################
    # The RawAccessRead event detects when a process conducts reading operations 
    # from the drive using the \\.\ denotation. This technique is often used by 
    # malware for data exfiltration of files that are locked for reading, as well 
    # as to avoid file access auditing tools. The event indicates the source 
    # process and target device.
    # https://devblogs.microsoft.com/scripting/use-powershell-to-interact-with-the-windows-api-part-1/
    ###############################################################################
    $TestName = "SYSMON_RAWACCESS_READ"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:

        # build the script to call
        $ScriptPath = "$($env:temp)\$($TestName).ps1"
        if (Test-Path -Path $ScriptPath) { Remove-Item -Path $ScriptPath -Force }
        $Content = @()
        $Content += "Import-Module PowerSploit -Force"
        $Content += "Invoke-NinjaCopy -Path `"$($env:windir)\system32\calc.exe`" -LocalDestination `"$($env:temp)\calc.exe`""
        Set-Content -Path $ScriptPath -Value $Content
        $Process = Start-Process -FilePath "Powershell.exe" -ArgumentList @("-version 2.0","-file $($ScriptPath)") -Wait -WindowStyle Hidden -PassThru
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2

    ################################################################################
    # SYSMON_FILE_CREATE: EventCode=11 RuleName=FileCreate
    ################################################################################
    # File create operations are logged when a file is created or overwritten. 
    # This event is useful for monitoring autostart locations, like the Startup 
    # folder, as well as temporary and download directories, which are common 
    # places malware drops during initial infection.
    ###############################################################################
    $TestName = "SYSMON_FILE_CREATE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $TemporaryFile = New-TemporaryFile
        Remove-Item $TemporaryFile -Force
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_REG_KEY: EventCode=12 RuleName=RegistryEvent (Object create and delete)
    ################################################################################
    $TestName = "SYSMON_REG_KEY"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        New-Item -Path HKLM:\Software\DeleteMe | Out-Null
        remove-item -Path HKLM:\Software\DeleteMe | Out-Null
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_REG_SETVALUE: EventCode=13 RuleName=RegistryEvent (Value Set)
    ################################################################################
    $TestName = "SYSMON_REG_SETVALUE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        New-Item -Path HKLM:\Software\DeleteMe  | out-null
        New-ItemProperty -Path HKLM:\Software\DeleteMe -Name Test -PropertyType String -Value "Hello World!" | out-null
        remove-item -Path HKLM:\Software\DeleteMe | out-null
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_FILE_CREATE_STREAM_HASH: EventCode=15 RuleName=FileCreateStreamHash
    ################################################################################
    $TestName = "SYSMON_FILE_CREATE_STREAM_HASH"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $TempFile = New-TemporaryFile
        $StreamName = "StreamMessage"
        $StreamText = "Hello World"
        Set-Content -Path $TempFile.FullName -Stream $StreamName -Value $StreamText
        $TempFile | Remove-Item -Force
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_CREATE_NAMEDPIPE: EventCode=17 RuleName=PipeEvent
    # https://stackoverflow.com/questions/24096969/powershell-named-pipe-no-connection
    ################################################################################
    $TestName = "SYSMON_CREATE_NAMEDPIPE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        # create a named pipe
        $pipeName = "testpipe$($i)"  
        $pipe = new-object System.IO.Pipes.NamedPipeServerStream $pipeName,'Out'
        $pipe.Dispose()
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2
    

    ################################################################################
    # SYSMON_CONNECT_NAMEDPIPE: EventCode=18 RuleName=PipeEvent
    ################################################################################
    $TestName = "SYSMON_CONNECT_NAMEDPIPE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        # build the script to run the pipe server
        $ScriptPath = "$($env:temp)\$($TestName).ps1"
        if (Test-Path -Path $ScriptPath) { Remove-Item -Path $ScriptPath -Force }
        $Content = @()
        $Content += "`$pipe = new-object System.IO.Pipes.NamedPipeServerStream 'testpipe','Out'"
        $Content += "`$pipe.WaitForConnection()"
        $Content += "`$sw = new-object System.IO.StreamWriter `$pipe"
        $Content += "`$sw.AutoFlush = `$true"
        $Content += "`$sw.WriteLine(`"Server pid is `$pid`")"
        $Content += "`$sw.Dispose()"
        $Content += "`$pipe.Dispose()"
        Set-Content -Path $ScriptPath -Value $Content
        $Process = Start-Process -FilePath "Powershell.exe" -ArgumentList @("-file $($ScriptPath)") -PassThru -WindowStyle Hidden

        # create a named pipe
        $pipe = new-object System.IO.Pipes.NamedPipeClientStream '.','testpipe','In'
        $pipe.Connect()
        $sr = new-object System.IO.StreamReader $pipe
        while (($data = $sr.ReadLine()) -ne $null) { write-debug "Received: $data"}
        $sr.Dispose()
        $pipe.Dispose()
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_WMI_FILTER: EventCode=19 RuleName=WmiEvent
    # SYSMON_WMI_CONSUMER: EventCode=20 RuleName=WmiEvent
    # SYSMON_WMI_BINDING: EventCode=21 RuleName=WmiEvent
    ################################################################################
    $TestName = "SYSMON_WMI_CONSUMER"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $command = 'powershell.exe -Command {write-host "hello world!"}'

        $Filter = Set-WmiInstance -Namespace root/subscription -Class __EventFilter -Arguments @{
               EventNamespace = 'root/cimv2'
               Name = "TestFilter"
               Query = "SELECT * FROM __InstanceCreationEvent WITHIN 10 WHERE TargetInstance ISA 'Win32_Process' AND Name='calc.exe'"
               QueryLanguage = 'WQL'
        }

        $Consumer = Set-WmiInstance -Namespace root/subscription -Class CommandLineEventConsumer -Arguments @{
               Name = "TestConsumer"
               CommandLineTemplate = $Command
        }

        $Binding = Set-WmiInstance -Namespace root/subscription -Class __FilterToConsumerBinding -Arguments @{
               Filter = $Filter
               Consumer = $Consumer
        }

        #Cleanup
        Get-WmiObject __EventFilter  -namespace root\subscription  | ?{$_.Name -eq "TestFilter"} | Remove-WmiObject
        Get-WmiObject CommandLineEventConsumer  -Namespace root\subscription  | ?{$_.Name -eq "TestConsumer"} | Remove-WmiObject
        Get-WmiObject __FilterToConsumerBinding   -Namespace root\subscription  | ?{$_.filter -match "TestFilter"} | Remove-WmiObject
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2
    
     
    ################################################################################
    # SYSMON_DNS_QUERY: EventCode=22 RuleName=DnsQuery
    ################################################################################
    $TestName = "SYSMON_DNS_QUERY"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        Resolve-DnsName -Name "www.google.com" | Out-Null
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


    ################################################################################
    # SYSMON_FILE_DELETE: EventCode=23 RuleName=FileDelete
    ################################################################################
    $TestName = "SYSMON_FILE_DELETE"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        $TemporaryFile = New-TemporaryFile
        Add-Content -Value "Hello World!" -Path $TemporaryFile.FullName
        Remove-Item -Path $TemporaryFile.FullName -Force
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2

    ################################################################################
    # SYSMON_CLIPBOARD: EventCode=24 RuleName=ClipboardChange
    ################################################################################
    $TestName = "SYSMON_CLIPBOARD"

    if ($ConstrainSysmonCollection -eq $True) {
        $configpath = make-sysmon-config -name $TestName -sysmonPath $sysmonPath
        reset-sysmon -sysmonPath $sysmonpath -configpath $configpath
    }

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"Begin`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message

    $TestStart = (get-date) ; $TestCount = 0
    do
    {
        $TestCount++
        ###########################################################################
        # Payload:
        Set-Clipboard -Value "Hello World!"
        ###########################################################################
    
    } until ((New-TimeSpan -Start $TestStart).TotalSeconds -ge $TestDurationTotalSeconds)

    $Message = "$(format-splunktime) TestName=`"$($TestName)`" TestDurationTotalSeconds=`"$($TestDurationTotalSeconds)`" TestStatus=`"End`" TestCount=`"$($TestCount)`""	
    write-host $Message ; add-content -Path $LogFile -Value $Message
    Start-Sleep -Seconds 2


}
until ($x -gt 0)

