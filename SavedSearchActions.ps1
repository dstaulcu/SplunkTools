<#
https://docs.splunk.com/Documentation/Splunk/7.3.2/RESTREF/RESTsearch#saved.2Fsearches
#>

$Items = @()
$hash = @{ ACTION_ID = 1; ACTION_NAME = "Change Owner"} ; $Items += New-Object -TypeName PSObject -Property $hash
$hash = @{ ACTION_ID = 2; ACTION_NAME = "Change Schedule Window"} ; $Items += New-Object -TypeName PSObject -Property $hash #schedule_window
$hash = @{ ACTION_ID = 3; ACTION_NAME = "Change Search Text"} ; $Items += New-Object -TypeName PSObject -Property $hash #search
$hash = @{ ACTION_ID = 4; ACTION_NAME = "Change Cron Schedule"} ; $Items += New-Object -TypeName PSObject -Property $hash  #cron_schedule
$hash = @{ ACTION_ID = 5; ACTION_NAME = "Change Description"} ; $Items += New-Object -TypeName PSObject -Property $hash #description
$hash = @{ ACTION_ID = 6; ACTION_NAME = "Change earliest time"} ; $Items += New-Object -TypeName PSObject -Property $hash #dispatch.earliest_time
$hash = @{ ACTION_ID = 7; ACTION_NAME = "Change latest time"} ; $Items += New-Object -TypeName PSObject -Property $hash #dispatch.latest_time
$hash = @{ ACTION_ID = 8; ACTION_NAME = "Disable"} ; $Items += New-Object -TypeName PSObject -Property $hash #disabled




$SelectedItems = $Items | select-object -Property ACTION_ID, ACTION_NAME | Sort-Object -Property ACTION_ID | Out-GridView -PassThru
$SelectedItems