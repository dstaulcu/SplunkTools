$ProviderName = "Microsoft-Windows-Sysmon"
$ProviderType = "Operational"

$Events = (Get-WinEvent -ListProvider $ProviderName).Events | ?{$_.LogLink.LogName -match $ProviderType}
$Results = @()

foreach ($Event in $Events ) {
    $printline = ""
    $dataElements = ($event.Template -split "\n") | Select-String -Pattern "data name"
    $dataElementsClean = @()
    foreach ($dataElement in $dataElements) {
        $dataElement -match "data name=`"([^`"]+)" | Out-Null
        $dataName = $Matches[1]
        $dataElementsClean += $dataName

        if ($printline -eq "" ) {
            $printline = $dataName
        } else {
            $printline += ", $($dataName)"
        }
    }

    if (($printline -ne "") -and ($Event.LogLink.LogName -match $ProviderType)) {
        $SPL = "source=`"XmlWinEventLog:$($Event.LogLink.LogName)`" EventID=$($event.id) | eval Description=`"$($event.Description)`" | table _time host Description $($printline)"
        $Info = @{
            "LogName" = $event.LogLink.LogName
            "EventID" = $event.Id
            "Level" = $event.Level.DisplayName
            "Version" = $event.Version
#            "Description" = $event.Description
            "SPL" = $SPL 
        }
        $Results += New-Object -TypeName PSObject -Property $Info

#        if (($Event.Id -eq 60) -and ($Event.Version -eq 1)) { break }

    }
}

$Selected = $Results | Sort-Object -Property LogName, EventID, Version | Select-Object -Property LogName, EventID, Version, Level, SPL | Out-GridView -Title "Select logs to add to clipboard" -PassThru

if ($Selected) {
    write-host "Selected Searches added to clipboard"
    $Selected.SPL | clip
}


