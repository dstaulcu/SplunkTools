param (
    [parameter(Mandatory=$true)][string]$TargetHost
)

$DateThreadStart = get-date

$RandomDuration = (Get-Random -Minimum 1 -Maximum 35)
Start-Sleep -Seconds $RandomDuration

$DateThreadEnd = Get-Date
$DurationThread = (New-TimeSpan -Start $DateThreadStart -End $DateThreadEnd).TotalMilliseconds

$myObject = [PSCustomObject]@{
    TargetHost = $TargetHost
    StartDate = $DateThreadStart
    EndDate  = $DateThreadEnd
    DurationMs = $DurationThread
    Test = "Sleep $($RandomDuration) seconds"
}

return $myObject