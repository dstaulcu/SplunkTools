<# 
Purpose:  Powershell script to download list of apps on splunkbase, prompt for selection, and initiate download via browser that pre-authenticated to splunkbase
Credit:  methods exposed in Analysis Of SplunkBase Apps for Splunk (https://splunkbase.splunk.com/app/2919/)
Credit:  methods exposed in Splunkbase-download project (https://github.com/tfrederick74656/splunkbase-download)
#>

$ProjectFolder = "C:\Apps\splunkbase"
$SupportFolder = "$($ProjectFolder)\support"
$AppsToTrack = "$($SupportFolder)\splunkAppsInteresting.csv"
$MyApps = Import-Csv -Path $AppsToTrack | ?{$_.interesting -eq "x"} | Select-Object -ExpandProperty path
$MyAppsRegex = $MyApps -join "|"
$MyAppsRegex = "`($($MyAppsRegex )`)"

$BookmarkFile = "$($SupportFolder)\LastModifiedDate.md"

# if bookmark file exists, get the date it contains
if (Test-Path -Path $BookmarkFile) {
    [datetime]$BookmarkDate = Get-Content -Path $BookmarkFile
} else {
    $BookmarkDate =  Get-Date -Date "06/26/2020"
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

function Get-Splunkbase-AppInfo {
    param($AppID)

    $WebRequest = Invoke-WebRequest -Uri "https://splunkbase.splunk.com/app/$($AppID)/" 

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

# get latest version in case tweaks were made at source
Set-Location -Path $ProjectFolder
& git.exe pull


## gather cred from credstore
$mycredfile = "$($SupportFolder)\mycred.xml"
if (!(Test-Path -Path $mycredfile)) {
    Get-Credential -Message "Enter credential for Splunkbase" | Export-Clixml -path $mycredfile
}
$cred = Import-Clixml $mycredfile

# Get cookie from splunk sesssion for use with CURL later.
$Cookie = Get-Splunkbase-SessionCookie -credFilePath $mycredfile


# first run just to get the amount of pages to iterate over.
$url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=1&offset=0"
$response = invoke-webrequest $url
$content = $response.Content | ConvertFrom-Json   

# gather all of the content available over pages
$results = @()
for ($offset = 0; $offset -le $content.total; $offset += 100)
{
    write-host "Getting next 100 results from offset $($offset) [total=$($content.total)]"
    $url = "https://splunkbase.splunk.com/api/v1/app/?order=latest&limit=100&offset=$($offset)"
    $response = invoke-webrequest $url
    $content = $response.Content | ConvertFrom-Json   
    $results += $content.results
}


# reduce list down to those which had an update (updated_time) recently
$Selected = $results | ?{$_.path -match $MyAppsRegex}
$Selected = $selected | ?{[datetime]$_.updated_time -le $BookmarkDate} | Sort-Object -Property updated_time
$Selected | %{"$($_.title) - $($_.updated_time)"}


$counter = 0
$Failures = @()
foreach ($item in $selected | ?{$_.path -match $MyAppsRegex}) {
    $counter++

    # get latest version for app by appid
    $AppInfo = Get-Splunkbase-AppInfo -appid $item.uid

    if ($AppInfo.version -notmatch "^\d") { 
        write-host "Download url for `"$($item.title)`" doesn't look right. Skipping!"
    } else {

        # build download url from base + appid + app version
        $Down_URL = "https://splunkbase.splunk.com/app/$($AppInfo.id)/release/$($AppInfo.version)/download/"

        write-host "Downloading `"$($item.title)`" from $($Down_URL)`"...."
        $filepath = "$ProjectFolder\$($appinfo.filename)"
        $ArgumentList = @("--cookie `"$($Cookie)`"","$($Down_URL)","--output $($filepath)","-L","-#")
        $process = Start-Process -FilePath "$($SupportFolder)\curl.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait

        if (!(Test-Path -Path $filepath)) {
            write-host "there was a problem with download; exit."
            exit
        }

        # identify the file to extract
        $list = & "$($SupportFolder)\7z.exe" l -ba $filepath -y
        $list -match "\s+\S+\s+\d+\s+\d+\s+(.*)" | Out-Null
        $tarFilePath = "$ProjectFolder\$($matches[1])"

        # extract the TGZ file
        write-host "-extract TGZ file $($filepath)..."
        $ArgumentList = @("e",$filepath,"-o`"$ProjectFolder\`"","-y")
        $process = Start-Process -FilePath "$($SupportFolder)\7z.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait

        if (!(Test-Path -Path $tarFilePath)) {
            write-host "there was a problem extracting TAR file; exiting."
            exit
        }

        # extract the TAR file
        write-host "-extract TAR file $($tarFilePath)..."
        $ArgumentList = @("x",$tarFilePath,"-o`"$ProjectFolder\`"","-y","-r","-aoa")
        $process = Start-Process -FilePath "$($SupportFolder)\7z.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait

        # cleanup download files
        if (Test-Path -Path $filepath) { Remove-Item -Path $filepath -Force }
        if (Test-Path -Path $tarFilePath) { Remove-Item -Path $tarFilePath -Force }


        # remove the old app in the apps subfolder, if exists, before copying new app in.    
        $Directories = Get-ChildItem -Path $ProjectFolder -Directory
        $NewDirectory = $Directories | ?{$_.name -notmatch "^(Support|Apps)$"}
        $TempPath = "$($ProjectFolder)\apps\$($NewDirectory.Name)"
        if (Test-Path -Path $TempPath) { Remove-Item -Path $TempPath -Recurse -Force }
        $NewDirectory | Move-Item -Destination $TempPath
    }

}

# add new assets to git
& git.exe add -A

# commit the content
$commitDate = (get-date).ToString()
& git.exe commit -m "splunkbase $($commitDate)"

# push the content
& git.exe push

Set-Content -Path $BookmarkFile -Value $commitDate
