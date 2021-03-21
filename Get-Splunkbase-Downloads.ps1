<#
$DebugPreference = "Continue"
#>

$ProjectFolder = "C:\Apps\splunkbase"
$SupportFolder = "$($ProjectFolder)\support"
$AppsToTrack = "$($SupportFolder)\myapps.csv"
$BookmarkFile = "$($SupportFolder)\LastModifiedDate.md"
$CatalogFile =  "$($ProjectFolder)\catalog.csv"

# if catalog file is missing, start anew
if (-not(test-path -path $CatalogFile)) {
    if (Test-Path -Path $BookmarkFile) { remove-item -Path $BookmarkFile }
}
# if bookmark file exists, get the date it contains
if (Test-Path -Path $BookmarkFile) {
    [datetime]$BookmarkDate = Get-Content -Path $BookmarkFile
} else {
    $BookmarkDate =  Get-Date -Date "01/01/1970"
}


function Get-Splunkbase-SessionCookie {
    param($credFilePath)
    $cred = Import-Clixml $credFilePath
    $user = $cred.UserName
    $pass = [System.Net.NetworkCredential]::new("", $cred.Password).Password

    ## establish logon session to splunk via okta
    $BASE_AUTH_URL='https://account.splunk.com/api/v1/okta/auth'
    $Body = @{
        username = $user
        password = $pass
    }
    $WebRequest = Invoke-WebRequest $BASE_AUTH_URL -SessionVariable 'Session' -Body $Body -Method 'POST' -UseBasicParsing
    if (!($WebRequest.StatusCode -eq "200")) {
        write-host "There was a problem authenticating to Splunk.  Exit."
        exit
    }
    $ssoid_cookie = (($WebRequest.Content | ConvertFrom-Json).cookies).ssoid_cookie
    $sid = ($Session.Cookies.GetCookies("https://splunkbase.splunk.com") | ?{$_.Name -eq "sid"}).Value

    $Cookie = "sid=$($sid); SSOSID=$($ssoid_cookie)"

    return $Cookie
}

function Get-Splunkbase-Session {
    param($credFilePath)
    $cred = Import-Clixml $credFilePath
    $user = $cred.UserName
    $pass = [System.Net.NetworkCredential]::new("", $cred.Password).Password

    ## establish logon session to splunk via okta
    $BASE_AUTH_URL='https://account.splunk.com/api/v1/okta/auth'
    $Body = @{
        username = $user
        password = $pass
    }
    $WebRequest = Invoke-WebRequest $BASE_AUTH_URL -SessionVariable 'Session' -Body $Body -Method 'POST' -UseBasicParsing
    if (!($WebRequest.StatusCode -eq "200")) {
        write-host "There was a problem authenticating to Splunk.  Exit."
        exit
    }

    $ssoid_cookie = (($WebRequest.Content | ConvertFrom-Json).cookies).ssoid_cookie

    $cookie = New-Object System.Net.Cookie    
    $cookie.Name = "SSOSID"
    $cookie.Value = $ssoid_cookie
    $cookie.Domain = ".splunk.com"
    $session.Cookies.Add($cookie);

    return $session
}

function Get-Splunkbase-AppInfo {
    param($AppID=4023,$session=$null)

    $WebRequest = Invoke-WebRequest -Uri "https://splunkbase.splunk.com/app/$($appid)/" -WebSession $session

    # EXTRACT OUT THE APP VERSION

    $element = $WebRequest.AllElements | ?{
        $_.class -eq "u.item:1/1@*" -and 
        $_.tagname -eq "DIV" -and 
        $_.innerhtml -match "sb-selector=`"release-version`"" -and
        $_.innerhtml -match "u-for=`"download-modal`"" -and
        $_.innerhtml -match "checksum" -and
        $_.outertext -match "^Downloading"}
    

    # extract out the release version (sb-target value)
    $version = "unknown"
    $filename = "unknown"
    $m = $element.innerHTML | select-string -pattern 'sb-target=\"([^\"]+)\".*?checksum \(([^\)]+)\)' -AllMatches
    if ($m) { 
        $version = $m.matches.captures[0].Groups[1].value 
        $filename = $m.matches.captures[0].Groups[2].value
    } else {
        $version = "none"
        $filename = "none"
    }

    # EXTRACT OUT THE SPLUNK VERSIONS SUPPORTED BY THIS VERSION OF APP
       
    # get all container info
    $element = $WebRequest.AllElements | ?{
        $_.class -eq "u.container:vspace-xs@* u.container:vpad-md" -and
        $_.tagname -eq "DIV" -and 
        $_.innerhtml -match "/apps/#/version/"
    }

    # find the sb-release section associated with our known release and extract out the list of hyperlinks
    $splunkVersions = "unknown"
    $pattern = 'sb-target=\"' + $version + '\" sb-selector="release-version">Splunk Versions:\s(.*?) <\/SB-RELEASE-SELECT>'
    $m = $element.innerHTML | select-string -pattern $pattern -AllMatches
    if ($m) {

        $versionLinks = $m.Matches.captures[0].Groups[1].Value

        # extract out the splunk versions from the list of links
        $m = $versionLinks | select-string -pattern 'version\/([^\"]+)' -AllMatches
    
        # transform the array of links to a pipe delimited string
        [object]$CaptureValues = @()
        for ($i = 0; $i -le $m.matches.Count -1; $i++)
        { 
            $CaptureValue = $m.Matches.Captures[$i].groups[1].Value     
            $CaptureValues += $CaptureValue
        }
        [string]$splunkVersions = $CaptureValues -join "|"
    } else {
        $splunkVersions = "none"
    }

    # EXTRACT OUT THE CIM VERSIONS SUPPORTED BY THIS VERSION OF APP

    # get all container info
    $element = $WebRequest.AllElements | ?{
        $_.class -eq "u.container:vspace-xs@* u.container:vpad-md" -and
        $_.tagname -eq "DIV" -and 
        $_.innerhtml -match "/apps/#/version/"
    }

    # find the sb-release section associated with our known release and extract out the list of hyperlinks
    $CIMVersions = "unknown"
    $pattern = 'sb-target=\"' + $version + '\" sb-selector="release-version">CIM Versions:\s(.*?) <\/SB-RELEASE-SELECT>'
    $m = $element.innerHTML | select-string -pattern $pattern -AllMatches
    if ($m) {
        $versionLinks = $m.Matches.captures[0].Groups[1].Value

        # extract out the splunk versions from the list of links
        $m = $versionLinks | select-string -pattern 'cim\/([^\"]+)' -AllMatches

        # transform the array of links to a pipe delimited string
        [object]$CaptureValues = @()
        for ($i = 0; $i -le $m.matches.Count -1; $i++)
        { 
            $CaptureValue = $m.Matches.Captures[$i].groups[1].Value     
            $CaptureValues += $CaptureValue
        }
        [string]$CIMVersions = $CaptureValues -join "|"
    } else {
        $CIMVersions = "none"    
    }

    # put all this juicy extracted content into an object to return from function
    $AppInfo = [pscustomobject]@{
        version = $version
        filename = $filename
        splunkVersions = $splunkVersions
        CIMVersions = $CIMVersions
        id=$appid
    }

    # return new object with desired info
    return $AppInfo
 
}

# gather cred from credstore
$mycredfile = "$($SupportFolder)\mycred.xml"
if (-not(Test-Path -Path $mycredfile)) {
    Get-Credential -Message "Enter credential for Splunkbase" | Export-Clixml -path $mycredfile
}
$cred = Import-Clixml $mycredfile

$Session = Get-Splunkbase-Session -credFilePath $mycredfile


# first run just to get the amount of pages to iterate over.
$url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=1&offset=0"
$response = invoke-webrequest $url -WebSession $session -UseBasicParsing
$content = $response.Content | ConvertFrom-Json

# gather all of the content available over pages
$results = @()
for ($offset = 0; $offset -le $content.total; $offset += 100)
{
    write-debug "Getting next 100 results from offset $($offset) [total=$($content.total)]"
    $url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=100&offset=$($offset)"
    $response = invoke-webrequest $url -WebSession $Session -UseBasicParsing
    $content = $response.Content | ConvertFrom-Json   
    $results += $content.results
}

# Get current date/time of our query of splunkbase.  We will commit this as our bookmark if we get to end of script
$LastQueryDate = Get-Date

# Import the last version of catalog from file if prsent.
if (test-path -path $catalogfile) { $CachedCatalog = Import-csv -Path $CatalogFile }



$counter = 0
foreach ($item in $results) {
    $counter++

    write-debug "[Item $($counter) of $($results.count)] - Gathering info on `"$($item.title)`" having uid `"$($item.uid)`"."

    # Check to see splunk base entry is newer than last evaluation
    if ([datetime]$item.updated_time -gt $BookmarkDate) {

        # scrape additional information about app (version, filename, splunk versions supported) from webpage for app on splunkbase
        $AppInfo = Get-Splunkbase-AppInfo -appid $item.uid

        # add discovered properties to the results array
        write-debug "`t-Scraped app version `"$($AppInfo.version)`", splunk versions `"$($appinfo.splunkVersions)`", and CIM versions `"$($appinfo.CIMVersions)`" to app record in results array."
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "version" -Value $AppInfo.version
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "splunkVersions" -Value $AppInfo.splunkVersions
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "CIMVersions" -Value $AppInfo.CIMVersions    

    } else {
        # Since entry is not newer, import app info from last update file instead of web (much faster)
    
        # pull up app record from object representing previously imported file
        $Entry = $CachedCatalog | ?{$_.uid -eq $item.uid}
        write-debug "`t-Imported app version `"$($Entry.version)`", splunk versions `"$($Entry.splunkVersions)`", and CIM versions `"$($Entry.CIMVersions)`" to app record in results array."

        # add version value to member of results array
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "version" -Value $entry.version
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "splunkVersions" -Value $entry.splunkVersions
        Add-Member -InputObject $item -MemberType NoteProperty -Force -Name  "CIMVersions" -Value $entry.CIMVersions

    }

}

# commit results array appended with additional properties to file
$results | Export-Csv -Path $CatalogFile -NoTypeInformation

# update bookmark file with date of last run
Set-Content -Path $BookmarkFile -Value $LastQueryDate.ToString()

