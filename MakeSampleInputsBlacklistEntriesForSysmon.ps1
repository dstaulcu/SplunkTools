$sysmonSchema = & sysmon.exe -s
$sysmonSchema = $sysmonSchema | select-string -Pattern "<"
[xml]$sysmonSchemaXML = $sysmonSchema

$i=0
$content = ""
foreach ($event in $sysmonSchemaXML.manifest.events.event) {
    $i++
    $MessageString = ""
    foreach ($item in $event.data) {
        if ($MessageString -eq "") {
            $MessageString = "Message=`"(?i)^$($item.name):\s+(.*)"
        } else {
            $MessageString += "\s+$($item.name):\s+(.*)"
        }
    }
    $MessageString += "\s+$($item.name):\s+(.*)$`""
    if ($content -eq "") {
        $content = "# Sample blacklist entries for Sysmon schemaversion $($sysmonSchemaXML.manifest.schemaversion)"
        $content += "`nblacklist$($i) = EventCode=`"^$($event.value)$`" $($MessageString)"
    } else {
        $content += "`nblacklist$($i) = EventCode=`"^$($event.value)$`" $($MessageString)"
    }
}

$content

<#

# Sample blacklist entries for Sysmon schemaversion 4.21
blacklist1 = EventCode="^255$" Message="(?i)^UtcTime:\s+(.*)\s+ID:\s+(.*)\s+Description:\s+(.*)\s+Description:\s+(.*)$"
blacklist2 = EventCode="^1$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+FileVersion:\s+(.*)\s+Description:\s+(.*)\s+Product:\s+(.*)\s+Company:\s+(.*)\s+OriginalFileName:\s+(.*)\s+CommandLine:\s+(.*)\s+CurrentDirectory:\s+(.*)\s+User:\s+(.*)\s+LogonGuid:\s+(.*)\s+LogonId:\s+(.*)\s+TerminalSessionId:\s+(.*)\s+IntegrityLevel:\s+(.*)\s+Hashes:\s+(.*)\s+ParentProcessGuid:\s+(.*)\s+ParentProcessId:\s+(.*)\s+ParentImage:\s+(.*)\s+ParentCommandLine:\s+(.*)\s+ParentCommandLine:\s+(.*)$"
blacklist3 = EventCode="^2$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetFilename:\s+(.*)\s+CreationUtcTime:\s+(.*)\s+PreviousCreationUtcTime:\s+(.*)\s+PreviousCreationUtcTime:\s+(.*)$"
blacklist4 = EventCode="^3$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+User:\s+(.*)\s+Protocol:\s+(.*)\s+Initiated:\s+(.*)\s+SourceIsIpv6:\s+(.*)\s+SourceIp:\s+(.*)\s+SourceHostname:\s+(.*)\s+SourcePort:\s+(.*)\s+SourcePortName:\s+(.*)\s+DestinationIsIpv6:\s+(.*)\s+DestinationIp:\s+(.*)\s+DestinationHostname:\s+(.*)\s+DestinationPort:\s+(.*)\s+DestinationPortName:\s+(.*)\s+DestinationPortName:\s+(.*)$"
blacklist5 = EventCode="^4$" Message="(?i)^UtcTime:\s+(.*)\s+State:\s+(.*)\s+Version:\s+(.*)\s+SchemaVersion:\s+(.*)\s+SchemaVersion:\s+(.*)$"
blacklist6 = EventCode="^5$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+Image:\s+(.*)$"
blacklist7 = EventCode="^6$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ImageLoaded:\s+(.*)\s+Hashes:\s+(.*)\s+Signed:\s+(.*)\s+Signature:\s+(.*)\s+SignatureStatus:\s+(.*)\s+SignatureStatus:\s+(.*)$"
blacklist8 = EventCode="^7$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+ImageLoaded:\s+(.*)\s+FileVersion:\s+(.*)\s+Description:\s+(.*)\s+Product:\s+(.*)\s+Company:\s+(.*)\s+OriginalFileName:\s+(.*)\s+Hashes:\s+(.*)\s+Signed:\s+(.*)\s+Signature:\s+(.*)\s+SignatureStatus:\s+(.*)\s+SignatureStatus:\s+(.*)$"
blacklist9 = EventCode="^8$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+SourceProcessGuid:\s+(.*)\s+SourceProcessId:\s+(.*)\s+SourceImage:\s+(.*)\s+TargetProcessGuid:\s+(.*)\s+TargetProcessId:\s+(.*)\s+TargetImage:\s+(.*)\s+NewThreadId:\s+(.*)\s+StartAddress:\s+(.*)\s+StartModule:\s+(.*)\s+StartFunction:\s+(.*)\s+StartFunction:\s+(.*)$"
blacklist10 = EventCode="^9$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+Device:\s+(.*)\s+Device:\s+(.*)$"
blacklist11 = EventCode="^10$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+SourceProcessGUID:\s+(.*)\s+SourceProcessId:\s+(.*)\s+SourceThreadId:\s+(.*)\s+SourceImage:\s+(.*)\s+TargetProcessGUID:\s+(.*)\s+TargetProcessId:\s+(.*)\s+TargetImage:\s+(.*)\s+GrantedAccess:\s+(.*)\s+CallTrace:\s+(.*)\s+CallTrace:\s+(.*)$"
blacklist12 = EventCode="^11$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetFilename:\s+(.*)\s+CreationUtcTime:\s+(.*)\s+CreationUtcTime:\s+(.*)$"
blacklist13 = EventCode="^12$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetObject:\s+(.*)\s+TargetObject:\s+(.*)$"
blacklist14 = EventCode="^13$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetObject:\s+(.*)\s+Details:\s+(.*)\s+Details:\s+(.*)$"
blacklist15 = EventCode="^14$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetObject:\s+(.*)\s+NewName:\s+(.*)\s+NewName:\s+(.*)$"
blacklist16 = EventCode="^15$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+Image:\s+(.*)\s+TargetFilename:\s+(.*)\s+CreationUtcTime:\s+(.*)\s+Hash:\s+(.*)\s+Hash:\s+(.*)$"
blacklist17 = EventCode="^16$" Message="(?i)^UtcTime:\s+(.*)\s+Configuration:\s+(.*)\s+ConfigurationFileHash:\s+(.*)\s+ConfigurationFileHash:\s+(.*)$"
blacklist18 = EventCode="^17$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+PipeName:\s+(.*)\s+Image:\s+(.*)\s+Image:\s+(.*)$"
blacklist19 = EventCode="^18$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+PipeName:\s+(.*)\s+Image:\s+(.*)\s+Image:\s+(.*)$"
blacklist20 = EventCode="^19$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+Operation:\s+(.*)\s+User:\s+(.*)\s+EventNamespace:\s+(.*)\s+Name:\s+(.*)\s+Query:\s+(.*)\s+Query:\s+(.*)$"
blacklist21 = EventCode="^20$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+Operation:\s+(.*)\s+User:\s+(.*)\s+Name:\s+(.*)\s+Type:\s+(.*)\s+Destination:\s+(.*)\s+Destination:\s+(.*)$"
blacklist22 = EventCode="^21$" Message="(?i)^RuleName:\s+(.*)\s+EventType:\s+(.*)\s+UtcTime:\s+(.*)\s+Operation:\s+(.*)\s+User:\s+(.*)\s+Consumer:\s+(.*)\s+Filter:\s+(.*)\s+Filter:\s+(.*)$"
blacklist23 = EventCode="^22$" Message="(?i)^RuleName:\s+(.*)\s+UtcTime:\s+(.*)\s+ProcessGuid:\s+(.*)\s+ProcessId:\s+(.*)\s+QueryName:\s+(.*)\s+QueryStatus:\s+(.*)\s+QueryResults:\s+(.*)\s+Image:\s+(.*)\s+Image:\s+(.*)$"


#>
