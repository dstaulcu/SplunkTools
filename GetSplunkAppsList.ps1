<# 
Purpose:  Powershell script to download list of apps on splunkbase, prompt for selection, and initiate download via browser that pre-authenticated to splunkbase
Credit:  methods exposed in Analysis Of SplunkBase Apps for Splunk (https://splunkbase.splunk.com/app/2919/)
#>

# path to desired browser
$browser_path = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

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

$selected = $results | where-object {$_.archive_status -eq "live"} | 
    Sort-object -property updated_time -descending |
    Select-Object -Property title, path, download_count, install_count, access, archive_status, appinspect_passed, updated_time | 
    Out-GridView -Title "Select items to download" -PassThru

$counter = 0

$Failures = @()

foreach ($item in $selected) {
    $counter++
    $response = Invoke-WebRequest -Uri $item.path

    # Find the DIV element of expected class having release-version info
    $element = $response.AllElements | ?{
        $_.class -eq "u.item:1/1@*" -and 
        $_.tagname -eq "DIV" -and 
        $_.innerhtml -match "sb-selector=`"release-version`"" -and
        $_.innerhtml -match "u-for=`"download-modal`"" -and
        $_.innerhtml -match "checksum" -and
        $_.outertext -match "^Downloading"}

    # extract out the release version (sb-target value)
    $element.innerHTML -match "sb-target=`"(\d+\.\d+\.\d+)`"" | Out-Null
    $release_version = $matches[1]

    if ($release_version) {

        # extract out the sha256 and filename for release version
        $element.innerHTML -imatch "SHA256 checksum \(([^)]+)\)\s+([a-z0-9]+)" | Out-Null
        $filename = $Matches[1]
        $sha256 = $Matches[2]

        # build the URL and do the download
        $download_url = "$($item.path)release/$($release_version)/download/"

        write-host "Downloading item $($counter) of $($selected.count) ($($item.title)) from $($download_url)`""

      #  start-process -FilePath $browser_path -ArgumentList $download_url

    } else {

        write-host "NOT Downloading item $($counter) of $($selected.count) ($($item.title)) due to inability to extract release version."
        $failures += $item
    }

}


$Failures_file = New-TemporaryFile 
$failures | Out-GridView
