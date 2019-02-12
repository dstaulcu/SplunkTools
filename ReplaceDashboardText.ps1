function get-splunk-search-results {

    param ($cred, $server, $port, $search)

    # This will allow for self-signed SSL certs to work
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $url = "https://${server}:${port}/services/search/jobs/export" # braces needed b/c the colon is otherwise a scope operator
    $the_search = "$($search)" # Cmdlet handles urlencoding
    $body = @{
        search = $the_search
        output_mode = "csv"
          }
    
    $SearchResults = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300
    return $SearchResults
}

function set-splunk-object-value {
    param ($server, $port, $cred, $object_id, $valuename, $valuedata)

    # This will allow for self-signed SSL certs to work
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $search_id = ($search.id).replace(($search.id).Split("/")[2],"$($server):$($port)")
    $url = "$($search_id)/acl" 
    
    $body = @{
        $valuename = $valuedata
          }

    write-host "Posted $($url) with the follwing arguments."
    $body
    
    Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300

}


function GetMatches([string] $content, [string] $regex) {
    $returnMatches = new-object System.Collections.ArrayList
    ## Match the regular expression against the content, and    
    ## add all trimmed matches to our return list    
    $resultingMatches = [Regex]::Matches($content, $regex, "IgnoreCase")    
    foreach($match in $resultingMatches)    {        
        $cleanedMatch = $match.Groups[1].Value.Trim()        
        [void] $returnMatches.Add($cleanedMatch)    
    }
    $returnMatches 
}


# Define path to windiff tool, allowing for human review of changes:
$windiff_filepath = 'C:\Program Files (x86)\Support Tools\windiff.exe'
$chrome_filepath = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'

# Define the pattern to look for 
$Pattern = '(?i)(sourcetype\s?=\s?"?(xml)?wineventlog:[^\s]+)'

# grab instance specific search head/user info:
$server = "splunk-dev.cloudapp.net"
$port = "8089"
if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "admin" }


# get saved dashboards into results object
$results = get-splunk-search-results -server $server -port $port -cred $cred -search "| rest /servicesNS/-/-/data/ui/views splunk_server=local | rename eai:* as *, acl.* as * | fields appName, sharing, userName, owner, title, updated, data"
if (!($results)) { 
    write-host "no results found, exiting."
    exit 
}
$results = ConvertFrom-Csv -InputObject $results

# enumerate each result (instance of dashboard) looking for pattern of concern (sourcetype field has more than xmlWinEventLog or WinEventLog)
$records = @()
foreach ($view in $results) {

    $Matches = GetMatches -content $view.data -regex $Pattern

    if ($Matches) {

        $data_newtext = $view.data
        $unique_matches = $matches | Select-Object -Unique
        foreach ($match in $unique_matches) {
            $match_newtext = $match -replace "sourcetype","source"
            $data_newtext = $data_newtext -replace $match,$match_newtext
        }


        $record = @{
            'appName' =  $view.appName
            'sharing' = $view.sharing
            'userName' = $view.userName
            'owner' = $view.owner
            'title' = $view.title
            'updated' = $view.updated
            'match_count' = $Matches.count
            'matches' = $Matches
#            'url_edit' = $edit_url 
            'data' = $view.data
            'new_data' = $data_newtext
        }

        $records += New-Object -TypeName PSObject -Property $Record

    }
}


$Selected = $records | Select-object title, updated, match_count, matches | Out-GridView -PassThru  -Title 'Selected view to update.'
if (!$Selected) {
    write-host "nothing selected, exiting."
    exit 
} else {
    foreach ($item in $selected) {
        $this_item_detail = $records | ?{$_.title -eq $item.title}

        # write orig content to a file
        $origfile = "$($env:temp)\$($this_item_detail.title).orig"
        if (Test-Path -Path $origfile) { Remove-Item -Path $origfile -Force }
        Add-Content -Path $origfile -Value $this_item_detail.data

        # write new content to a file
        $newfile = "$($env:temp)\$($this_item_detail.title).new"
        if (Test-Path -Path $newfile) { Remove-Item -Path $newfile -Force }
        Add-Content -Path $newfile -Value $this_item_detail.new_data

        # launch windiff to human review proposed change in content of two files
        Start-Process -filepath $windiff_filepath -argumentlist @($origfile,$newfile) -Wait

        # ask user if human review was acceptable and if so, do change.
        $Response = @("Yes - Lets edit the dashboard now","No - Lets defer the change for now") | Out-GridView -Title "Proceed with change to $($this_item_detail.title)?" -PassThru
        if ($Response -match "^Yes") {     

            # build url which will enable open of dashboard in edit mode 
            $edit_url = "http://$($server):8000/en-US/app/$($this_item_detail.appName)/$($this_item_detail.title)/editxml?"

            # writing new item data to clipboard
            $this_item_detail.new_data | clip

            # start new browser tab where admin can paste and save updated content
            Start-Process -filepath $chrome_filepath -argumentlist @($edit_url) -Wait
        }

        
    }


}
