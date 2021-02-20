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

# iterate through items and add to records object
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


# get list of apps present
$Apps = Get-ChildItem -Path $SplunkApps -Directory
$AppRecords = @()

# categorize apps as built-in, deployed, or local based on factors
foreach ($app in $Apps) {

    # assume app is local, "Local"
    $AppType = "Local"

    # if app has name of known local apps change value to "built-in"
    if ($app.Name -match "^(.*Splunk-FileAndDirectoryEliminator.*|introspection_generator_addon|learned|search|SplunkUniversalForwarder|splunk_httpinput|splunk_internal_metrics)$") {
        $AppType = "Built-In"
    } 

    # if app has name present in list apps in serverlcass change value to "deployed"
    if ($Records.app -match $app.name) {
        $AppType = "Deployed"
    }

    $Info = @{
        "Name" = $app.Name
        "Type" = $AppType
    }

    $AppRecords += New-Object -TypeName PSObject -Property $Info
 
}

# write-output records in recordset in format optimized for tanmium input
foreach ($AppRecord in $AppRecords | ?{$_.type -ne "Built-in"}) {
    $recordString = ($AppRecord | ConvertTo-Csv -NoTypeInformation)[1]
    $recordString = $recordString -replace ",","|"
    $recordString = $recordString -replace "`"",""
    Write-Output $recordString
}


