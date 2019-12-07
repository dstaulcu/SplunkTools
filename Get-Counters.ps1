<#
.Synopsis
   Collects select performance counters until a specified process exists
.EXAMPLE
   Invoke via scheduled task when interactive user logs on and flush results session is fully loaded
.TODO
   Write output to Splunk as metrics via HEC
   Add fail safe termination event in case
#>

$ProcessToWaitFor = "^notepad$"

$SampleIntervalSeconds = 1
$FailsafeWaitDurationSeconds = 60*1

# http://www.appadmintools.com/documents/windows-performance-counters-explained/
$Counters = @(
    '\Memory\Available Bytes',
    '\Memory\Cache Bytes',
    '\Memory\Page Reads/sec',
    '\Memory\Page Writes/sec',
    '\Memory\Pages/sec',
    '\Memory\Pool Nonpaged Bytes',
    '\Network Interface(*)\Bytes Received/sec',
    '\Network Interface(*)\Bytes Sent/sec',
    '\Paging File(_total)\% Usage',
    '\PhysicalDisk(*)\Avg. Disk Queue Length',
    '\PhysicalDisk(*)\Avg. Disk sec/Read',
    '\PhysicalDisk(*)\Avg. Disk sec/Write',
    '\PhysicalDisk(*)\Current Disk Queue Length',
    '\PhysicalDisk(*)\Disk Read Bytes/sec',
    '\PhysicalDisk(*)\Disk Write Bytes/sec',
    '\PhysicalDisk(*)\Split IO/sec',
    '\Process(*)\% Processor Time',
    '\Process(*)\Handle Count',
    '\Process(*)\IO Data Bytes/sec',
    '\Process(*)\Working Set',
    '\Process(_Total)\Working Set',
    '\Processor(*)\% Privileged Time',
    '\Processor(*)\% User Time',
    '\Processor(_total)\% Processor Time',
    '\System\Processor Queue Length'
)

$ResultsFile = "$($env:temp)\Records.csv" 
if (Test-Path -Path $ResultsFile) { Remove-Item -Path $ResultsFile -Force }

$NumberOfLogicalProcessors = (Get-CimInstance -ClassName win32_processor -Property NumberOfLogicalProcessors)[0].NumberOfLogicalProcessors
$StartTime = get-date

do {
    

    try {

        $Records = @()

        $Samples = Get-Counter -Counter $Counters -MaxSamples 1 -ErrorAction SilentlyContinue

        foreach ($Sample in $Samples.CounterSamples) {
      
            $Path = $Sample.Path -split "\\"
            $Computer = $Path[2]
            $Object = ($Path[3] -split "\(")[0]

            $Counter = $Path[4]
            $Counter = $Counter -replace "%","pct"
            $Counter = $Counter -replace "/","_per_"
            $Counter = $Counter -replace "\s","_"
            if ($Path[3] -match "\((\w+)\)") { $Instance = $Matches[1] } else { $Install = $null }
            $Value =  [math]::round($Sample.CookedValue,5)

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

        # filter out un-needed 0 valued or _total instance process records
        $records = $records | where { -not ($_.object -eq "process" -and ($_.instance -eq "_total" -or $_.value -eq 0)) }

        # commit records to file
        $Records | export-csv -NoTypeInformation -Path $ResultsFile -Append

    } catch { write-host "there was an error" }

    Start-Sleep -seconds $SampleIntervalSeconds

    if (((Get-Process).name -match $ProcessToWaitFor) -or ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds -ge $FailsafeWaitDurationSeconds)) { $blnProcessRunning = $true } else { $blnProcessRunning = $false }


} while ($blnProcessRunning -eq $false)

<# For interactive testing

Import-Csv -Path $ResultsFile | Sort-Object -Property TimeStamp, Computer, Object, Instance, Counter | Select-Object TimeStamp, Computer, Object, Instance, Counter, Value | Out-GridView 

& $ResultsFile

#>
