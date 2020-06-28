# User Preferences
$AreasOfInterest = @(", US$")   # all of selected contries 
$AreasOfInterest = @(", Virginia, US",", Maryland, US")  # all of selected states
$AreasOfInterest = @("Fairfax, Virginia, US","Montgomery, Maryland, US","Prince George's, Maryland, US","Baltimore, Maryland, US","Anne Arundel, Maryland, US","Prince William, Virginia, US","Loudoun, Virginia, US","Howard, Maryland, US","Frederick, Maryland, US","Arlington, Virginia, US")


# ----------------------------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------------------------

# transform counties of interest to a regular expression pattern to match
$RegexPattern = $AreasOfInterest -join "|"
$RegexPattern = "`($($RegexPattern)`)"

# download the latest covid datasets (if local copy older than 20 hours)
$url = "https://github.com/CSSEGISandData/COVID-19/archive/master.zip"
$download = "$($env:temp)\master.zip"
write-host "-downloading new COVID-19 datasets from $($url)."
if (!(Test-Path -Path $download -NewerThan (Get-Date).AddHours(-20))) {
    $Response = Invoke-WebRequest -Uri $url -OutFile $download
}

# extract the compressed content (if local copy older than 20 hours)
write-host "-extracting COVID-19 dataset archive."
$extracted = "$($env:temp)\extracted"
if (!(Test-Path -Path $extracted -NewerThan (Get-Date).AddHours(-20))) {
    Expand-Archive -LiteralPath $download -DestinationPath $extracted -Force
}

# collate records of interest
$csse_covid_19_daily_reports = "$($extracted)\COVID-19-master\csse_covid_19_data\csse_covid_19_daily_reports"

$AllRecords = @()
write-host "-importing items WHERE Combined_Key -match `"$($RegexPattern)`""
$files = Get-ChildItem -Path $csse_covid_19_daily_reports -Recurse -Filter "*.csv"
$counter = 0
foreach ($file in $files) {
    $counter++
    $pctComplete = [math]::round(($counter / $files.Count)*100)
    Write-Progress -Activity "Extracting report data from $($file.name)" -Status "$($pctComplete)% complete" -PercentComplete $pctComplete
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
        Add-Member -InputObject $Record -MemberType NoteProperty -Force -Name  "County" -Value $Record.Admin2
    }
    # append records from file to full recordset
    $AllRecords += $Records  
}

# create a temporary file to work with
$tmpFile = New-TemporaryFile
$outputFile = $tmpFile.FullName -replace "$($tmpFile.Extension)$",".csv"
Rename-Item -Path $tmpFile -NewName $outputFile

# output records to CSV file
$AllRecords | Select SampleDate, Combined_Key, Country_Region, Province_State, County, Confirmed, Deaths, Incidence_Rate, Recovered, Case-Fatality_Ratio, SampleDateEpoch | export-csv -path $outputFile -NoTypeInformation -Force

# dispaly all records in grid view
$AllRecords = import-csv -path $outputfile 

# display all records in built-in CSV file reader (that's excel for mom!)
& $outputfile

