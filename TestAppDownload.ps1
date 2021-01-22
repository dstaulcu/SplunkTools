
<#
$DebugPreference = "Continue"
#>

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
    write-host "Invoking webrequest to build session token."
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

    write-host "Invoking webrequest to return app info."
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
    $element.innerHTML -match "sb-target=`"(\d+\.\d+\.\d+)`"" | Out-Null
    $version = $matches[1]
    $version

    # extract out the download filename
    $element.innerHTML -match " checksum \(([^\)]+)" | Out-Null
    $filename = $matches[1]
    $filename

    # return new object with desired info
    [PSCustomObject]@{
        filename=$filename
        version=$version
        id=$appid
    }
  

}

## gather cred from credstore
$workingPath = "c:\apps\splunkbase\support"
$mycredfile = "$($workingPath)\mycred.xml"
if (!(Test-Path -Path $mycredfile)) {
    Get-Credential -Message "Enter credential for Splunkbase" | Export-Clixml -path $mycredfile
}
$cred = Import-Clixml $mycredfile

# Get cookie from splunk sesssion for use with CURL later.
$Cookie = Get-Splunkbase-SessionCookie -credFilePath $mycredfile

# get latest version for app by appid
$AppID = 2686
$AppInfo = Get-Splunkbase-AppInfo -appid $AppID


# build download url from base + appid + app version
$Down_URL = "https://splunkbase.splunk.com/app/$($AppInfo.id)/release/$($AppInfo.version)/download/"

write-host "Download $($appinfo.filename) from $($Down_URL)`"...."
$filepath = "C:\Apps\splunkbase\$($appinfo.filename)"
$ArgumentList = @("--cookie `"$($Cookie)`"","$($Down_URL)","--output $($filepath)","-L","-#")
$process = Start-Process -FilePath "$($workingPath)\curl.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait

if (!(Test-Path -Path $filepath)) {
    write-host "there was a problem with download; exit."
    exit
}

# identify the file to extract
$list = & "$($workingPath)\7z.exe" l -ba $filepath -y
$list -match "\s+\S+\s+\d+\s+\d+\s+(.*)" | Out-Null
$tarFilePath = "C:\Apps\splunkbase\$($matches[1])"

# extract the TGZ file
write-host "extract TGZ file $($filepath)..."
$ArgumentList = @("e",$filepath,"-o`"C:\Apps\splunkbase\`"","-y")
$process = Start-Process -FilePath "$($workingPath)\7z.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait

if (!(Test-Path -Path $tarFilePath)) {
    write-host "there was a problem extracting TAR file; exiting."
    exit
}

# extract the TAR file
write-host "extract TAR file $($filepath2)..."
$ArgumentList = @("x",$tarFilePath,"-o`"C:\Apps\splunkbase\`"","-y","-r","-aoa")
$process = Start-Process -FilePath "$($workingPath)\7z.exe" -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru -Wait



