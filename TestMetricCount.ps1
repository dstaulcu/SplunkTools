<#
https://docs.splunk.com/Documentation/InfraApp/latest/Admin/ManualInstallWindowsUF
#>

<#
$DebugPreference = "Continue"           # Debug Mode
$DebugPreference = "SilentlyContinue"   # Normal Mode
#>

function Import-SplunkConfFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [String] $confFilePath
    )


    # get sample stanza file into object
    $confFileContent = Get-Content -Path $confFilePath 

    # filter content down to valid specs (not blank or commented lines)
    $confFileContent = $confFileContent | ?{$_ -match "\w+" -and $_ -notmatch "^\s*`#"}

    # initial stanzas object
    $stanzas = @()

    $lineCount = 0
    foreach ($line in $confFileContent) {
        $LineCount++

        # process stanza lines
        if ($line -match "^\[") {

            # if this is not the first line, add the last stanza to stanzas array
            if ($LineCount -ne 1) { 
                $stanzas += $stanza                
            } 

            # initialize a new stanza object
            $stanza = New-Object PSObject
            $stanza | Add-Member  -type NoteProperty -name "Stanza" -value $line
        }

        # process spec lines
        if ($line -match "\w+\s*=\s*\w") {
            # extract the key/value
            $Extraction = [regex]::Match($line,"^\s*(\S+)\s*=\s*(.*)")
            if ($Extraction.Success) {
                $Name = $Extraction.Groups[1].Value
                $Value = $Extraction.Groups[2].Value
                $stanza | Add-Member  -type NoteProperty -name $Name -value $Value
            }
        }
            
        # if this is the last line, add the current stanza to stanzas array
        if ($LineCount -eq $stanzasFileContent.count) {
            $stanzas += $stanza                
        }

   }
   return $stanzas
}

$confFilePath = "C:\Apps\inputs.conf.sample.txt"

if (!(Test-Path -Path $confFilePath)) {
    write-host "File `"$($confFilePath)`" Not Found.  Exiting."
    Exit
} 

$Inputs = Import-SplunkConfFile -confFilePath $confFilePath
$Inputs = $Inputs | ?{$_.Stanza -match "perfmon://"}

foreach ($input in $Inputs ) {

    # transform the counter names in the input object to a regular expression
    $inputCounters = $input.counters -replace ";","|"
    $inputCounters = "($($inputCounters))"


    # get the counter instances for the perfmon object of the current input
    $objectCounters = Get-Counter -ListSet $input.object
    if ($objectCounters.CounterSetType -eq "SingleInstance") {
        $MatchingInstances = $objectCounters.Paths -match $inputCounters
    } else {
        $MatchingInstances = $objectCounters.PathsWithInstances -match $inputCounters
    }
    
    # get the sample for each matching path
    $Counter = Get-Counter -Counter $MatchingInstances -MaxSamples 1
    Write-host "$($input.stanza) would send $($counter.CounterSamples.Count) datapoints to transform on each interval with instances undefined"
    
}






