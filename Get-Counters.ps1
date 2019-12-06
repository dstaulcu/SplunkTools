<#
.Synopsis
   Collects select performance counters until a specified process exists
.EXAMPLE
   Invoke via scheduled task when interactive user logs on and flush results when session is fully loaded for long logon bottleneck analysis
.TODO
   Write output to Splunk as metrics via HEC
#>

$ProcessToWaitFor = "notepad"

$SampleIntervalSeconds = 1

$ResultsFile = "$($env:temp)\Records.csv"

$Counters = @(
    '\processor(_total)\% processor time',
    '\process(*)\% processor time',
    '\memory\% committed bytes in use',
    '\memory\cache faults/sec',
    '\physicaldisk(_total)\% disk time',
    '\physicaldisk(_total)\current disk queue length'

)

$NumberOfLogicalProcessors = (Get-CimInstance -ClassName win32_processor -Property NumberOfLogicalProcessors)[0].NumberOfLogicalProcessors

$Records = @()

do {
    try {

        $Samples = Get-Counter -Counter $Counters -MaxSamples 1 -ErrorAction SilentlyContinue

        foreach ($Sample in $Samples.CounterSamples) {
            
            $Path = $Sample.Path -split "\\"
            $Computer = $Path[2]
            $Object = ($Path[3] -split "\(")[0]
            $Counter = $Path[4]
            $Counter = $Counter -replace "%","pct"
            $Counter = $Counter -replace "/","_per_"
            $Counter = $Counter -replace "\s","_"
            $Path[3] -match "\((\w+)\)" | Out-Null ; $Instance = $Matches[1]
            $Value = $Sample.CookedValue

            if ($Object -eq "Process" -and $Counter -eq "pct_processor_time") { $value = $Value / $NumberOfLogicalProcessors }

            $Record = @{
                "Computer" = $Computer
                "TimeStamp" = $Sample.TimeStamp
                "Object" = $Object
                "Instance" = $Instance
                "Counter" = $Counter
                "Value" = $Value
            }

            $Records += New-Object -TypeName PSObject -Property $Record

        }  

    } catch {}

    Start-Sleep -seconds $SampleIntervalSeconds

    if ((Get-Process).name -match $ProcessToWaitFor) { $blnProcessRunning = $true } else { $blnProcessRunning = $false }

} while ($blnProcessRunning -eq $false)

# filter out un-needed records
$records = $records | where { -not ($_.object -eq "process" -and $_.Counter -eq "pct_processor_time" -and ($_.instance -eq "_total" -or $_.value -eq 0)) }

# commit records to file
if (Test-Path -Path $ResultsFile) { Remove-Item -Path $ResultsFile -Force }
$Records | export-csv -NoTypeInformation -Path $ResultsFile

# prepare records for display
# $Records | Sort-Object -Property TimeStamp, Computer, Object, Instance, Counter | Select-Object TimeStamp, Computer, Object, Instance, Counter, Value | Out-GridView
