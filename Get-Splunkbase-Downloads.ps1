<#
.SYNOPSIS
	Download selected apps from splunkbase in either interactive or unattended mode
.PARAMETER app_id_list
	download filter based on comma separated list of ids of apps. (all by default)
.PARAMETER app_age_days
	download filter based on number of days since last update. (7 days by default)
.PARAMETER download_path
	path to folder where download files are saved. (%temp% by default)
.PARAMETER cred_file_path
	path to file having credentials stored as secure string (prompt for credentials by default)
.PARAMETER unattended
	boolean ($true or $false) denoting whether script should run unattended. cred_file_path parameter required.
.NOTES
    check for updates here: https://github.com/dstaulcu/SplunkTools	
.EXAMPLE
    .\get-splunkbase-downloads.ps1 -download_path C:\Apps\Splunkbase
.EXAMPLE
    .\get-splunkbase-downloads.ps1 -download_path C:\Apps\Splunkbase -app_age_days 7 -cred_file_path C:\Apps\Splunkbase\support\mycred.xml -app_id_list "1914,742" -unnatended $true
#>


param([string]$download_path="$($env:temp)"
    ,[int]$app_age_days="7"
    ,[string]$app_id_list=$null
    ,[string]$cred_file_path=$null
    ,[boolean]$unattended=$false
)

<##############################################################################
FUNCTIONS 
##############################################################################>

## with input of appid, query splunkbase for version number and file name and return in appinfo object.
function Get-Splunkbase-AppInfo {
    param($AppID,$session)

    $WebRequest = Invoke-WebRequest -Uri "https://splunkbase.splunk.com/app/$($AppID)/" -WebSession $session

    # Find the DIV element of expected class having release-version info
    $element = $WebRequest.AllElements | ?{
        $_.class -eq "u.item:1/1@*" -and 
        $_.tagname -eq "DIV" -and 
        $_.innerhtml -match "sb-selector=`"release-version`"" -and
        $_.innerhtml -match "u-for=`"download-modal`"" -and
        $_.innerhtml -match "checksum" -and
        $_.outertext -match "^Downloading"}

    # extract out the release version (sb-target value)
    $element.innerHTML -match "sb-target=`"([^\`"]+)`"" | Out-Null
    $version = $matches[1]

    # extract out the download filename
    $element.innerHTML -match " checksum \(([^\)]+)" | Out-Null
    $filename = $matches[1]

    # return new object with desired info
    [PSCustomObject]@{
        filename=$filename
        version=$version
        id=$appid
    }
 
}


<##############################################################################
 MAIN
##############################################################################>


# confirm path of download_path parameter
if (!(Test-Path -Path $download_path)) {
    write-host "Path to download folder `"$($download_path)`" not found. Exiting"
    exit
}

# handle cred_file_path paramter
if (!($cred_file_path)) {
    # prompt for cred if file not supplied
    $cred = Get-Credential -Message "Enter credential for Splunkbase"
    if (!($cred)) {
        write-host "User cancelled credential gathering process. Exiting."
        exit
    } 
} else {
    # validate path if file supplied as parameter
    if (Test-Path -Path $cred_file_path) {
        $cred = Import-Clixml $cred_file_path
    } else {
        write-host "Invalid path to cred file - `"$($cred_file_path)`". Exiting."
        exit
    }
}

# handle unattended parameter
    if ($unattended) {
        if (!($cred_file_path)) {
            write-host "Error - cred_file_path parameter must be defined in unattended mode. Exiting."
            exit
        }
    }

# handle app id list parameter (transform to support regex matching)
if ($app_id_list) {
    $app_id_list = $app_id_list -Split ','
    $app_id_list = $app_id_list -join "|"   
    $app_id_list = "^($($app_id_list)$"
} else {
    $app_id_list = ".*"
}


## establish logon session to splunk via okta

$user = $cred.UserName
$pass = [System.Net.NetworkCredential]::new("", $cred.Password).Password

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

## scrape the ssoid from server response and append as cookie to websession object
$cookie = New-Object System.Net.Cookie    
$cookie.Name = "SSOSID"
$cookie.Value = (($WebRequest.Content | ConvertFrom-Json).cookies).ssoid_cookie
$cookie.Domain = ".splunk.com"
$session.Cookies.Add($cookie);

<# show cookies 
$Session.Cookies.GetCookies("https://splunk.com") | select Name, Value, Domain
#>

# first run just to get the amount of pages to iterate over.
$url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=1&offset=0"
$webrequest = invoke-webrequest $url -WebSession $session -UseBasicParsing
$content = $webrequest.Content | ConvertFrom-Json   

# gather all of the content available over pages.  
$results = @()
for ($offset = 0; $offset -le $content.total; $offset += 100)
{
    $pctComplete = [math]::round(($offset/$content.total)*100,0)
    Write-Progress -Activity "Splunkbase Manifest Download in Progress" -Status "$pctComplete% Complete:" -PercentComplete $pctComplete;
    $url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=100&offset=$($offset)"
    $webrequest = invoke-webrequest $url -WebSession $Session -UseBasicParsing
    $content = $webrequest.Content | ConvertFrom-Json
    
    $results += $content.results

    <#
    # if last record in current page of results is older than age of content we want to download, break out of routine with what we've got.
    if ($app_age_days) {
        if ((new-timespan -start ([datetime]($content.results | sort-object -property updated_time | Select-Object -first 1 -ExpandProperty updated_time))).TotalDays -ge $app_age_days) {
            break
        }
    }
    #>

}


# build list of items to download from manifest
$itemsToDownload = $results | Select-Object -Property updated_time, title, path, archive_status, access, download_count, install_count, uid | Sort-Object -Property updated_time -descending

# reduce list of items to download to those which match app_id_list parameter
$itemsToDownload = $itemsToDownload | ?{$_.uid -match $app_id_list}

# reduce list of items to download to those which meet app_age_days parameter constraint
$itemsToDownload = $itemsToDownload | Where-Object {(new-timespan -start ([datetime]$_.updated_time)).TotalDays -le $app_age_days}

if ($unattended -eq $false) {
    # prompt user to further reduce list interactively
    $itemsToDownload = $itemsToDownload | Out-GridView -Title "Select Splunkbase items to download" -PassThru
}

# download items selected from gridview
$counter = 0
$Failures = @()
foreach ($item in $itemsToDownload) {
    $counter++

    $pctComplete = [math]::round(($counter/$itemsToDownload.count)*100,0)
    Write-Progress -Activity "Working on download of `"$($item.title)`"" -Status "$pctComplete% Complete:" -PercentComplete $pctComplete;

    # get latest version for app by appid
    $AppInfo = Get-Splunkbase-AppInfo -appid $item.uid

    if ($AppInfo.version -notmatch "^\d") { 
        write-host "Download url for `"$($item.title)`" doesn't look right. Skipping."  -ForegroundColor Yellow
        continue
    }

    # build download url from base + appid + app version
    $Down_URL = "https://splunkbase.splunk.com/app/$($AppInfo.id)/release/$($AppInfo.version)/download/"

    # build the file path to download the item to
    $filepath = "$download_path\$($appinfo.filename)"

    try {
        $WebRequest = Invoke-WebRequest -Uri $Down_URL -WebSession $Session -OutFile $filepath
        write-host "`nWebRequest for download of `"$($item.title)`" having access type of `"$($item.access)`" succeeded."
        write-host "-Download path: `"$($filepath)`""
    } catch { 
        write-host "`nWebRequest for download of `"$($item.title)`" having access type of `"$($item.access)`" failed." -ForegroundColor Yellow
        write-host "-Download url:  `"$($down_url)`"" -ForegroundColor Yellow
        write-host "-Exception message:  `"$($Error[0].Exception.Message)`"" -ForegroundColor Yellow
        continue
    }

}
write-host ""
write-host ""