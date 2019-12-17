
# Grab the events from a DC            
$Events = Get-WinEvent  -MaxEvents 100 -FilterHashtable @{
    Logname='Microsoft-Windows-Sysmon/Operational'
    Id=1
    }
            
# Parse out the event message data            
ForEach ($Event in $Events) {  
          
    # Convert the event to XML            
    $eventXML = [xml]$Event.ToXml()            

    # Iterate through each one of the XML message properties            
    For ($i=0; $i -lt $eventXML.Event.EventData.Data.Count; $i++) {            
        # Append these as object properties
        $ValueName = $eventXML.Event.EventData.Data[$i].name
        $ValueData = $eventXML.Event.EventData.Data[$i].'#text'             
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name $ValueName  -Value $ValueData
    }            
}      

if ($Events) {      
            
    # View the results with your favorite output method            
    $Selected = $Events | Select-Object * | Out-GridView -PassThru -Title "Select an event to build a blacklist entry for"

    foreach ($item in $Selected) {
        $schema = ($item.Message -split "\r\n")

        $Elements = @()

        $counter = 0
        foreach ($element in $schema) {
            $counter++
            if ($counter -ge 1) {
                $elementInfo = $element -split ":\s"
                $elementNames += $elementInfo[0]
                $elementValue = $elementInfo[1]

                $info = @{
                    "elementNumber" = $counter
                    "elementName" = $elementInfo[0]
                    "elementValue" = $elementInfo[1]
                }
                $Elements += New-Object -TypeName PSObject -Property $info


            }
        }
    }

    $selectedElements = $Elements | Select-Object -Property elementNumber, elementName, elementValue | Sort-Object -Property elementNumber | Out-GridView -Title "Select elements to factor into regex" -PassThru

    foreach ($item in $Selected) {
        $schema = ($item.Message -split "\r\n")
        $counter = 0

        $content = ""
        $MessageString = ""

        foreach ($element in $schema) {
            $counter++
            if ($counter -ne 1) {
                $elementInfo = $element -split ":\s"
                $elementName = $elementInfo[0]
                $elementValue = $elementInfo[1]


                if ($selectedElements.elementname -match "^$($elementName)$") {
                } else {
                    $elementValue = "(.*)"
                }

                if ($elementValue -ne "(.*)") { $elementValue = [regex]::Escape($elementValue) }

                if ($MessageString -eq "") {
                    $MessageString = "Message=`"(?i)^$($elementName):\s+$($elementValue)"
                } else {
                    $MessageString += "\s+$($elementName):\s+$($elementValue)"
                }

            }

        }

       if ($content -eq "") {
            $content = "# Sample blacklist entries for Sysmon schemaversion $($sysmonSchemaXML.manifest.schemaversion)"
            $content += "`nblacklist# = EventCode=`"^$($item.Id)$`" $($MessageString)"
        } else {
            $content += "`nblacklist# = EventCode=`"^$($item.Id)$`" $($MessageString)"
        }

    }

    $content | clip
}
