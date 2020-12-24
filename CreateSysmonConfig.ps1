$sysmonPath = "$($env:windir)\sysmon.exe"
if (!(Test-Path -Path $sysmonPath)) {
    write-host "Sysmon.exe not present in $($sysmonPath). Exiting."
    exit
} 



# Get sysmon schema into xml
$sysmonSchemaPrint = & $sysmonPath -s 2> $null | Select-String -Pattern "<"
$sysmonSchemaPrintXml = [xml]$sysmonSchemaPrint

# Stop if version is less than 4.22
if ($sysmonSchemaPrintXml.manifest.schemaversion -lt 4.22) {
    write-host "Sysmon.exe binary does not support schema version 4.22 or higher. Exiting."
    exit    
}

# spit out a new template file
$events = $sysmonSchemaPrintXml.manifest.events.event | Where-Object {$_.name -notmatch "(SYSMON_ERROR|SYSMON_SERVICE_STATE_CHANGE|SYSMON_SERVICE_CONFIGURATION_CHANGE)"}

$xmlConfig = @()
$xmlConfig += "<!--"
$xmlConfig += "  FILTERING: Filter conditions available for use are: $($sysmonSchemaPrintXml.manifest.configuration.filters.'#text')"
$xmlConfig += "-->"
$xmlConfig += ""
$xmlConfig += "<Sysmon schemaversion=`"$($sysmonSchemaPrintXml.manifest.schemaversion)`">"
$xmlConfig += ""
if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "HashAlgorithms") { $xmlConfig += "`t<HashAlgorithms>*</HashAlgorithms>" }
if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "DnsLookup") { $xmlConfig += "`t<DnsLookup/>" }
if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "CheckRevocation") { $xmlConfig += "`t<CheckRevocation/>" }
if ($sysmonSchemaPrintXml.manifest.configuration.options.option.name -match "ArchiveDirectory") { $xmlConfig += "`t<ArchiveDirectory/>" }
$xmlConfig += ""
$xmlConfig += "`t<EventFiltering>"

foreach ($event in $events) {
    $printConfig = $true
    $xmlConfig += ""
    # print the section hearder listing ID (value), Description (template), and config file section id (rulename)
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

    if ($printConfig -eq $true) {
        $xmlConfig += ""
        $xmlConfig += "`t`t<RuleGroup name=`"`" groupRelation=`"or`">"
        $xmlConfig += "`t`t`t<$($event.rulename) onmatch=`"include`">"
        $xmlConfig += "`t`t`t`t<!-- <Rule groupRelation=`"and`" name=`"`"> -->"

        $SampleObject = ($event.data | ?{$_.Name -notmatch "(RuleName|UtcTime|ProcessGuid|ProcessId|Archived)"})[0].Name
        $xmlConfig += "`t`t`t`t`t<!-- <$($SampleObject) condition=`"contains`">SomeValue</$($SampleObject)> -->"
        $SampleObject = ($event.data | ?{$_.Name -notmatch "(RuleName|UtcTime|ProcessGuid|ProcessId|Archived)"})[-1].Name
        $xmlConfig += "`t`t`t`t`t<!-- <$($SampleObject) condition=`"contains`">SomeValue</$($SampleObject)> -->"
       
        $xmlConfig += "`t`t`t`t<!-- </Rule> -->"                                
        $xmlConfig += "`t`t`t</$($event.rulename)>"
        $xmlConfig += "`t`t</RuleGroup>"
    }
}
$xmlConfig += ""
$xmlConfig += "`t</EventFiltering>"
$xmlConfig += ""
$xmlConfig += "</Sysmon>"


write-host "sample sysmon config file added to clipboard!"
$xmlConfig | clip
