# Image exclusions loaded from cfg file
$NetworkConnect_PTRLookup_ImageExclusions = @("^C:\\Program Files\\LGHUB\\lghub_agent.exe$","\\nvcontainer.exe$")

# Get some events to work with 
$Events = Get-WinEvent -FilterHashtable @{logname='Microsoft-Windows-Sysmon/Operational'; ID=3} -MaxEvents 500

# Evaluate events against exclusions
foreach ($Event in $Events) {

    # conver the event to xml
    $EventXML = [xml]$Event.ToXml()

    # Iterate through each one of the XML message properties and append them as propery of Event           
    For ($i=0; $i -lt $eventXML.Event.EventData.Data.Count; $i++) {            
        # Append these as object properties            
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  $eventXML.Event.EventData.Data[$i].name -Value $eventXML.Event.EventData.Data[$i].'#text'            
    }            

    # initialize marker depicting whether match was found
    $blnMatchFound = $false

    # PTR requests likely not cached already if connection was not initiated locally
    if ($Event.Initiated -eq "false") {

        #Check to see if event image matches exclusion list
        foreach ($NetworkConnect_PTRLookup_ImageExclusion in $NetworkConnect_PTRLookup_ImageExclusions) {

            # check twhether image in event matches this exclusion
            if ($Event.Image -imatch $NetworkConnect_PTRLookup_ImageExclusion) {   
                $blnMatchFound = $true
                $matchedExclusion = $NetworkConnect_PTRLookup_ImageExclusion
                break   # no need to proceed further with match checking for this event
            }
        }

        # Summarize event and disposition
        if ($blnMatchFound -eq $true) {
            write-host "Do not proceed with DNS PTR Request for incoming NetworkConnect event `"$($Event.RecordID)`" having image `"$($Event.Image)`" based on exclusion `"$($matchedExclusion)`""
        }
    }
}

