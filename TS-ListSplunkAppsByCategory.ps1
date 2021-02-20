$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$SplunkApps = "$($SplunkHome)\etc\apps"
$ServerclassXml = "$($SplunkHome)\var\run\serverclass.xml"


# check for presence of splunk home
if (-not (Test-Path -Path $SplunkHome)) {
    write-host "Path to splunk home `"$($SplunkHome)` not found. Exiting." 
    exit
}

# check for presence of splunk apps
if (-not (Test-Path -Path $SplunkApps)) {
    write-host "Path to splunk apps `"$($SplunkApps)` not found. Exiting." 
    exit
}

# check for presence of Serverclass.xml
if (-not (Test-Path -Path $SplunkHome)) {
    write-host "Path to serverclass `"$($ServerclassXml)` not found. Exiting." 
    exit
}

# read xml file into object
$ServerClass = [xml](Get-Content -Path $ServerclassXml)

$Records = @()

# iterate through items and build powershell object
if ($ServerClass.deployResponse) {   
    foreach ($class in $ServerClass.deployresponse.serverClass) {
        foreach ($app in $class.app) {

            $Info = @{
                "serverclass" = $class.name
                "app" = $app.name
                }

            $Records += New-Object -TypeName PSObject -Property $Info
        }
    }
}

############################################################################
# show apps which are local but not listed in serverclass
############################################################################

# get list of apps present
$Apps = Get-ChildItem -Path $SplunkApps -Directory

$AppRecords = @()

foreach ($app in $Apps) {

    $AppType = "Local"

    if ($app.Name -match "^(.*Splunk-FileAndDirectoryEliminator.*|introspection_generator_addon|learned|search|SplunkUniversalForwarder|splunk_httpinput|splunk_internal_metrics)$") {
        $AppType = "Built-In"
    } 

    if ($Records.app -match $app.name) {
        $AppType = "Deployed"
    }


    $Info = @{
        "Name" = $app.Name
        "Type" = $AppType
    }

    $AppRecords += New-Object -TypeName PSObject -Property $Info
 
}

# prepare records for output to tanium
foreach ($AppRecord in $AppRecords | ?{$_.type -ne "Built-in"}) {
    $recordString = ($AppRecord | ConvertTo-Csv -NoTypeInformation)[1]
    $recordString = $recordString -replace ",","|"
    $recordString = $recordString -replace "`"",""
    Write-Output $recordString
}


