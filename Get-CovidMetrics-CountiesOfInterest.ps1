# Cities of interest
$CountiesOfInterest = @("Richmond, Georgia, US","Fairfax, Virginia, US","Arlington, Virginia, US","Loudoun, Virginia, US","Pottawattamie, Iowa, US","Elbert, Georgia, US")
$CountiesOfInterest = @(", Georgia, US",", Virginia, US",", Virginia, US",", Virginia, US",", Iowa, US",", Georgia, US",", Florida, US",", Texas, US")

# Transfor counties of interest to a regular expression pattern to match
$RegexPattern = $CountiesOfInterest -join "|"
$RegexPattern = "`($($RegexPattern)`)"

# download the latest covid datasets
$url = "https://github.com/CSSEGISandData/COVID-19/archive/master.zip"
$download = "$($env:temp)\master.zip"
write-host "downloading COVID-19 dataset from url $($url)."
Start-BitsTransfer -Source $url -Destination $download

# extract the content
write-host "extracting COVID-19 dataset downloaded archive."
$extracted = "$($env:temp)\extracted"
if (Test-Path -Path $extracted) { Remove-Item -Path $extracted -Recurse }
Expand-Archive -LiteralPath $download -DestinationPath $extracted -Force
$extracted = "$($extracted)\COVID-19-master\csse_covid_19_data\csse_covid_19_daily_reports"

if (!(Test-Path -Path $extracted)) {
    write-host "Project data not found in $($extracted)."
    return 1
}

$AllRecords = @()

write-host "extracting items of interest."
$files = Get-ChildItem -Path $extracted -Recurse -Filter "*.csv"
$counter = 0
foreach ($file in $files) {
    $counter++
    $pctComplete = [math]::round(($counter / $files.Count)*100)
    Write-Progress -Activity "Extracting report data" -Status "$($pctComplete)% complete" -PercentComplete $pctComplete
    $SampleDate = $file.BaseName
    # convert report date string to date
    $SampleDateE = [DateTime]::ParseExact($SampleDate, 'MM-dd-yyyy', [CultureInfo]::InvariantCulture)
    # convert report date date to epoch
    $SampleDateE = (new-timespan -start "01/01/1970" -end $SampleDateE).TotalSeconds

    # import records from file to object
    $Records = Import-Csv -Path $file.FullName

    # filter out records to only include areas of interest
    $Records = $Records | ?{$_.Combined_Key -match $RegexPattern }
    foreach ($Record in $Records) {
        # append report dates in human time (excel) and epoch time (programming)
        Add-Member -InputObject $Record -MemberType NoteProperty -Force -Name  "SampleDate" -Value $SampleDate
        Add-Member -InputObject $Record -MemberType NoteProperty -Force -Name  "SampleDateEpoch" -Value $SampleDateE
    }
    # append records from file to full recordset
    $AllRecords += $Records  
}

# create a temporary file to work with
$tmpFile = New-TemporaryFile
$outputFile = $tmpFile.FullName -replace "$($tmpFile.Extension)$",".csv"

# output records to CSV file
$AllRecords | export-csv -path $outputFile -NoTypeInformation -Force

# dispaly all records in grid view
$AllRecords = import-csv -path $outputfile 

# display all records in built-in CSV file reader (that's excel for mom!)
& $outputfile

