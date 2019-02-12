<#
.Synopsis
   Find and replace strings of concern in splunk dashbaords, with human review.
.DESCRIPTION
   Lists dashbords and reports having specified pattern in search string
   Prompts user to select dashboard to update
   Shows user difference in preview and proposed new settings using Windiff
   Prompts user to confirm proposed changes
   Places accepted changes in clipboard
   Opens selected dashboard in browser for editing, where clipboard content and be pasted and saved.

.TO DO
   - Add support for saved searches
   - Add support for case where kos of same title exist in diferring apps
   - Think of ways to reduce prompting
   - Add logging of changes made
#>

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

# define splunk instance variables to use
$server = "splunk-dev"
$port = "8089"

# Define the pattern to look for 
$Pattern = '(?i)(sourcetype\s?=\s?"?(xml)?wineventlog:[^\s]+)'

# Define path to windiff tool, allowing for human review of changes:
$windiff_filepath = 'C:\Program Files (x86)\Support Tools\windiff.exe'
if (!(Test-Path -Path $windiff_filepath)) {
    write-host "Unable to verify support file in path $($windiff_filepath)."
    write-host 'Windiff is part of the the "Windows Server 2003 Resource Kit Tools" package which can be downloaded from https://www.microsoft.com/en-us/download/details.aspx?id=17657.'
    write-host 'Exiting.'
    exit
}

# Define path to preferred browser, which will later be used to open KOs for editing.
$browser_filepath = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
if (!(Test-Path -Path $browser_filepath)) {
    write-host "Unable to verify support file in path $($browser_filepath)."
    write-host 'Please update the browser_filepath variable in this script provide the path to your preferred browswer for administering splunk.'
    write-host 'Exiting.'
    exit
}

# collect credentials from user, securely, at runtime
if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "admin" }

# define the splunk search which returns a noramlized set of fields for savedsearches and views matching pattern of concern
$theSearch = '| rest /servicesNS/-/-/data/ui/views splunk_server=local 
| rename eai:appName as appName, eai:acl.owner as owner, eai:acl.sharing as sharing, eai:data as data, eai:type as type 
| fields type, appName, sharing, owner, title, updated, matching_values, data, id 
| append 
    [| rest/servicesNS/-/-/saved/searches splunk_server=local 
    | eval type="search" 
    | rename eai:acl.app as appName, eai:acl.owner as owner, qualifiedSearch as data 
    | fields type, appName, sharing, owner, title, updated, matching_values, data, id
        ] 
| regex data="(?msi)sourcetype\s?=\s?\"?(xml)?wineventlog:[^\s]+" 
| rex field=data "(?<matching_values>(?msi)sourcetype\s?=\s?\"?(xml)?wineventlog:[^\s]+)" 
| sort 0 appName, type, title'

# perform the search and return results as object 
$results = get-splunk-search-results -server $server -port $port -cred $cred -search $theSearch
if (!($results)) { 
    write-host "no results found, exiting."
    exit 
}
$results = ConvertFrom-Csv -InputObject $results

# enumerate matching knowledge object (view or savedsearch) 
$records = @()
foreach ($result in $results) {

    $Matches = GetMatches -content $result.data -regex $Pattern

    if ($Matches) {

        $data_newtext = $result.data
        $unique_matches = $matches | Select-Object -Unique
        foreach ($match in $unique_matches) {
            $match_newtext = $match -replace "sourcetype","source"
            $data_newtext = $data_newtext -replace $match,$match_newtext
        }


        $record = @{
            'appName' =  $result.appName
            'sharing' = $result.sharing
            'userName' = $result.userName
            'owner' = $result.owner
            'title' = $result.title
            'updated' = $result.updated
            'match_count' = $Matches.count
            'matches' = $Matches
#            'url_edit' = $edit_url 
            'data' = $result.data
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
        $Response = @("Yes - Put new content in my clipboard and open dashboard for editing in browser.","No - Lets defer the change for now") | Out-GridView -Title "Proceed with change to $($this_item_detail.title)?" -PassThru
        if ($Response -match "^Yes") {     

            # build url which will enable open of dashboard in edit mode 
            $edit_url = "http://$($server):8000/en-US/app/$($this_item_detail.appName)/$($this_item_detail.title)/editxml?"

            # writing new item data to clipboard
            $this_item_detail.new_data | clip

            # start new browser tab where admin can paste and save updated content
            Start-Process -filepath $browser_filepath -argumentlist @($edit_url) -Wait
        }

        
    }


}
