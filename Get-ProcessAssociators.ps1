function DatePicker($title) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
     
    $global:date = $null
    $form = New-Object Windows.Forms.Form
    $form.Size = New-Object Drawing.Size(233,190)
    $form.StartPosition = "CenterScreen"
    $form.KeyPreview = $true
    $form.FormBorderStyle = "FixedSingle"
    $form.Text = $title
    $calendar = New-Object System.Windows.Forms.MonthCalendar
    $calendar.ShowTodayCircle = $false
    $calendar.MaxSelectionCount = 1
    $form.Controls.Add($calendar)
    $form.TopMost = $true
     
    $form.add_KeyDown({
        if($_.KeyCode -eq "Escape") {
            $global:date = $false
            $form.Close()
        }
    })
     
    $calendar.add_DateSelected({
        $global:date = $calendar.SelectionStart
        $form.Close()
    })
     
    [void]$form.add_Shown($form.Activate())
    [void]$form.ShowDialog()
    return $global:date
}


function get-search-results {

    param ($cred, $server, $port, $search)

    # This will allow for self-signed SSL certs to work
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $url = "https://${server}:${port}/services/search/jobs/export" # braces needed b/c the colon is otherwise a scope operator
    $the_search = "search $($search)" # Cmdlet handles urlencoding
    $body = @{
        search = $the_search
        output_mode = "csv"
          }
    
    $SearchResults = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300
    return $SearchResults
}



# GET SERVER/CRED INFO FOR SPLUNK SEARCH
$server = "splunk-dev.cloudapp.net"
$port = "8089"
if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "davides-adm" }


# GET HOSTNAME INPUT FOR SPLUNK SEARCH
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$title = 'Process Analysis'
$msg   = 'Enter host name:'
$hostname = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
if ($hostname -eq $false) {
    write-host "Unexpected input, exiting."
    exit
}


# GET EARLIEST DATE INPUT FOR SPLUNK SEARCH
Try {
    $earliest = $(DatePicker "Start Date").ToShortDateString()
    $earliest += ":00:00:00" 
} catch {
    write-host "Unexpected input, exiting."
    exit
}


# GET LATEST DATE INPUT FOR SPLUNK SEARCH
Try {
    $latest = $(DatePicker "End Date").ToShortDateString()
    $latest += ":23:59:59" 
} catch {
    write-host "Unexpected input, exiting."
    exit
}

# INTEGRATE INPUTS INTO SEARCH STATEMENT
$search  = "source=`"*WinEventLog:Microsoft-Windows-Sysmon/Operational`" EventCode=1 
    host=$($hostname) 
    earliest=`"$($earliest)`" latest=`"$($latest)`"
    | table _time host EventCode EventDescription User Image CommandLine ParentImage ProcessGuid ProcessId ParentCommandLine ParentProcessGuid ParentProcessId
    | sort 0 _time"


# INVOKE SEARCH
write-host "Invoking search on $($server)..."
write-host "$($search)"
$results  = get-search-results -server $server -port $port -cred $cred -search $search
if (!($results)) { 
    write-host "no results found, exiting."
    exit 
}


# PRESENT RESULTS IN GRID VIEW SO USER CAN IDENTIFY TOP LEVEL PROCESS OF CONCERN
$results = ConvertFrom-Csv -InputObject $results
$Selected = $results | Out-GridView -PassThru  -Title 'Select Parent Event of Concern'
if (!$Selected) {
    write-host "nothing selected, exiting."
    exit 
}

# SEARCH CORPUS FOR ALL CHILDREN OF PROCESS OF CONCERN
$ParentProcessGuids = @($selected.ParentProcessGuid)
$DiscoveredGuids = $ParentProcessGuids
$DescendentEvents = @()
$RecursionLevel = 0

do {
    $blnFoundSome = $False
    ++$RecursionLevel

    $ProcessGuids = @()

    foreach ($Result in $Results) {

        if ($ParentProcessGuids -match $result.ParentProcessGuid) {
            $blnFoundSome = $True

            $CurrentEvent = @()
            $CurrentEvent = $Result
            $CurrentEvent | Add-Member -MemberType NoteProperty "Level" -Value $RecursionLevel

            $DescendentEvents += $CurrentEvent   

            $ProcessGuids += $result.ProcessGuid
        }
    }

    $ProcessGuids  = $ProcessGuids | Select-Object -Unique
    Write-Host "Completed loop $($RecursionLevel) and found $($ProcessGuids.count) new process guids within $($DescendentEvents.count) events."

    $DiscoveredGuids += $ProcessGuids
    $ParentProcessGuids = $ProcessGuids

} until ($blnFoundSome -eq $False)

Write-Host "Discovered a total of $($DiscoveredGuids.count) guids."


# NOW THAT WE HAVE ALL THESE GUIDS, WE COULD GO FURTHER TO FIND ALL OTHER CLASSES OF SYSMON EVENTS RELATING TO THEM
$DescendentEvents | Out-GridView


# TURN GUID ARRAY INTO SEARCH FILTER
$searchfilter_fields = "("
foreach ($DiscoveredGuid in $DiscoveredGuids) {
    if ($searchfilter_fields -eq "(") {
        $searchfilter_fields = "(ProcessGuid=`"$($DiscoveredGuid)`""
    } else {
        $searchfilter_fields += " OR ProcessGuid=`"$($DiscoveredGuid)`""
    }
}
$searchfilter_fields += ")"
$searchfilter_raw = $searchfilter -replace "ProcessGuid=",""
$searchfilter = "$($searchfilter_raw) AND $($searchfilter_fields)"
$searchfilter


# INTEGRATE INPUTS INTO SEARCH STATEMENT
$search = $search -replace "EventCode=1",$searchfilter


# INVOKE SEARCH
write-host "Invoking search on $($server)..."
write-host "$($search)"
$results  = get-search-results -server $server -port $port -cred $cred -search $search
if (!($results)) { 
    write-host "no results found, exiting."
    exit 
}

# PRESENT RESULTS IN GRID VIEW
$results = ConvertFrom-Csv -InputObject $results
$results | Out-GridView 


<#
next actions:
- now that we have the capability to return more than just process create events, we're going to have differing colun names of interest
- it might be best to return the second search as XML or JSON so that we can deal with the varying properties of each eventt type.

Once we have that in hand we can create a series of visualizations:
- process create histogram or tree
- network connection graph
#>