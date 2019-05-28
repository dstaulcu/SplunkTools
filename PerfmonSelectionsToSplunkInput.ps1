$SamplingInterval = 1000
$Interval = 300
$StatTypes = "average;count;dev;min;max"
$Index = "main"
$ComputerName = $env:computername


$Objects = Get-Counter -ListSet "*" -ComputerName $ComputerName
$ObjectsView = $Objects


$Records = @()

$SelectedObjects = $ObjectsView | Select CounterSetName, Description | Sort-Object -Property CounterSetName, Description | Out-GridView -Title "Select objects of interest" -PassThru
foreach ($Object in $SelectedObjects) {

    $SelectedObjectCounters = $Objects | ?{$_.CounterSetName -eq $Object.CounterSetName}

    $theseCounters = ""
    foreach ($SelectedObjectCounter in $SelectedObjectCounters.Counter) {

        $thisCounter = $SelectedObjectCounter -replace "\\.*\\",""

        if ($theseCounters -eq "") {
            $theseCounters = $thisCounter
        } else {
            $theseCounters += "; $($thisCounter)"
        }

    }

    $record = @{
    'object' =  ($object.CounterSetName).Trim()
    'counter' = ($theseCounters).Trim()
    }

    $records += New-Object -TypeName PSObject -Property $Record

}

# if records were selected, prepare sample splunk inputs and appent to file

if ($records) {

    $randomNumber = Get-Random -Minimum 1 -Maximum 1000
    $tmpFile = "$env:temp\splunktmp_$($randomNumber).txt"
    if (Test-Path -Path $tmpFile) { Remove-Item -Path $tmpFile }


    foreach ($Record in $Records) {

        Add-Content -Path $tmpFile -Value ""
        Add-Content -Path $tmpFile -Value "[perfmon://$($record.object)]"
        Add-Content -Path $tmpFile -Value "#counters = $($record.counter)"
        Add-Content -Path $tmpFile -Value "counters = *"
        Add-Content -Path $tmpFile -Value "disabled = 0"
        Add-Content -Path $tmpFile -Value "interval = $($Interval)"
        Add-Content -Path $tmpFile -Value "object = $($record.object)"
        Add-Content -Path $tmpFile -Value "useEnglishOnly=true"
        Add-Content -Path $tmpFile -Value "mode = multikv"
        Add-Content -Path $tmpFile -Value "samplingInterval = $($SamplingInterval)"
        Add-Content -Path $tmpFile -Value "stats = $($statTypes)"
        Add-Content -Path $tmpFile -Value "index = $($Index)"

    }

    Start-Process -FilePath "Notepad.exe" -ArgumentList $tmpFile -Wait
    if (Test-Path -Path $tmpFile) { Remove-Item -Path $tmpFile }
}


