# Image exclusions loaded from cfg file
$NetworkConnect_PTRLookup_ImageExclusions = @("C:\Program Files\Tanium\TaniumClient.exe","mcansvc2.exe")

Write-Host "`nUser supplied the following exclusions:" ; $NetworkConnect_PTRLookup_ImageExclusions ; "`b"

# Make events 
$Events = @()
$Events += New-Object -TypeName PSObject -Property @{Image = "C:\Program Files\Tanium\TaniumClient.exe"; User = ""; Protocol = "" ;Initiated = "false"; SourceIsIpv6 = ""; SourceIp = ""; SourceHostname = ""; SourcePort = ""; SourcePortName = ""; DestinationIsIpv6 = ""; DestinationIp = ""; DestinationHostname = ""; DestinationPort = ""; DestinationPortName = ""}
$Events += New-Object -TypeName PSObject -Property @{Image = "C:\Program Files\McAfee\mcansvc.exe"; User = ""; Protocol = "" ;Initiated = "false"; SourceIsIpv6 = ""; SourceIp = ""; SourceHostname = ""; SourcePort = ""; SourcePortName = ""; DestinationIsIpv6 = ""; DestinationIp = ""; DestinationHostname = ""; DestinationPort = ""; DestinationPortName = ""}


# Evaluate events against exclusions
foreach ($Event in $Events) {
   
    # initialize marker depicting whether match was found
    $blnMatchFound = $false

    # PTR requests likely not cached already if connection was not initiated locally
    if ($Event.Initiated -eq "false") {

        write-host "`nEvaluating rule against event:"
        $Event


        #Check to see if event image matches exclusion list
        foreach ($NetworkConnect_PTRLookup_ImageExclusion in $NetworkConnect_PTRLookup_ImageExclusions) {

            # escape chars supplied in exclusion prep for regex evaluation
            $NetworkConnect_PTRLookup_ImageExclusion_Escaped = [regex]::escape($NetworkConnect_PTRLookup_ImageExclusion)

            write-host "`nUser exclusion [$($NetworkConnect_PTRLookup_ImageExclusion)] escaped as [$($NetworkConnect_PTRLookup_ImageExclusion_Escaped)] for regex matching."

            if ($Event.Image -imatch $NetworkConnect_PTRLookup_ImageExclusion_Escaped) {   
                $blnMatchFound = $true
                # no need to proceed further with match checking for this event
                break               
            }
        }

        # in theory this would be just before call to dnslookup function
        if ($blnMatchFound -eq $true) {
            write-host "Disposition:  Skip DNS PTR Request for NetworkConnect event with Image: $($Event.Image)."
        } else {
            write-host "Disposition:  Proceed with DNS PTR Request for NetworkConnect event with Image: $($Event.Image)."
        }
    }
}

