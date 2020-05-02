<#
install-Module powershell-yaml -Force 
#>
import-Module powershell-yaml

$source = "https://github.com/Neo23x0/sigma/archive/master.zip"
$destination = "$($env:TEMP)\master.zip"
$project = $destination -replace ".zip",""

# download the file
Start-BitsTransfer -Source $source -Destination $destination

# remove previous versions of unzipped file, if exist
if (Test-Path -Path $project) {
    Remove-Item -Path $project -Force -Recurse
}

# expand the downloaded file to project folder
Expand-Archive -Path $destination -DestinationPath $project

# isolate to files of interest
$files = (Get-ChildItem -Path $project -Recurse -Filter "*.yml")
$files = $files | ?{$_.FullName -match "rules\\windows\\powershell"}

# get entries in files having pattern of cmdlet name
$patterns = $files | Get-Content |ConvertFrom-Yaml | Select-String -Pattern "^\S+-\S+$" | Select-String -notmatch "^http"

# get the unique patterns
$patterns = $patterns | Select-Object -Unique
$patterns = $patterns -replace "^\*",""
$patterns = $patterns -replace "\*$",""

$patternGroup = ""
foreach ($pattern in $patterns) {
    if ($patternGroup -eq "") {
        $patternGroup = $pattern
    } else {
        $patternGroup += "|$($pattern)"
    }

}

$ShortDate = Get-date -format "yyyy-MM-dd"
$stanza = @()
$stanza += "[WinEventLog://Microsoft-Windows-PowerShell/Operational]"
$stanza += "disabled = 0"
$stanza += "renderXml = true"
$stanza += "# needs a filtering strategy."
$stanza += "whitelist1 = EventCode=`"^(4100|4104)$`""
$stanza += "# Cmdlets of concern according to `"sigma`" repo on $($ShortDate)."
$stanza += "whitelist1 = EventCode=`"^4103$`" Message=`"(?i)Command Name\s+=\s+($($patternGroup))`""
$stanza += "# Any Scripts - Needs a filtering strategy"
$stanza += "whitelist2 = EventCode=`"^4103$`" Message=`"(?i)Command Type\s+=\s+Script`""   

$stanza | clip
$stanza
