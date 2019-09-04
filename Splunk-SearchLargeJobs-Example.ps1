<# To Do
# delete the job in splunk
# abstract everything to a set of functions to simplify main
# move print statements to verbose logging
#>


# https://docs.splunk.com/Documentation/Splunk/7.2.6/RESTTUT/RESTsearches
# http://dev.splunk.com/view/python-sdk/SP-CAAAEE5#searchjobparams

# define splunk instance variables to use
$server = "splunk-dev"
$port = "8089"
$maxResultRowsLimit = 50000   
 
 function create-searchjob {
 
 
     param ($cred, $server, $port, $search)
 
     # This will allow for self-signed SSL certs to work
     [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)
 
     $url = "https://${server}:${port}/services/search/jobs" # braces needed b/c the colon is otherwise a scope operator
     $the_search = "$($search)" # Cmdlet handles urlencoding
     $body = @{
         search = $the_search
         output_mode = "csv"
         count = "0"
         exec_mode = "normal"
         max_count = "0"
            }
     
     $response = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300
     return $response
 }
 
 function check-searchjobstatus {
 
 
     param ($cred, $server, $port, $jobsid)
 
     # This will allow for self-signed SSL certs to work
     [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)
 
     $url = "https://${server}:${port}/services/search/jobs/$($jobsid)"   
     $body = @{
         output_mode = "csv"
         count = "0"
         max_count = "0"
         exec_mode = "normal"
         offset = $offset
           }   
     $response = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -TimeoutSec 300
     return $response
 }
 
 function get-searchjob {
 
 
     param ($cred, $server, $port, $jobsid, $offset=0)
 
     # This will allow for self-signed SSL certs to work
     [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)
 
     $url = "https://${server}:${port}/services/search/jobs/$($jobsid)/results/" 
     $body = @{
         output_mode = "csv"
         count = "0"
         max_count = "0"
         exec_mode = "normal"
         offset = $offset

           }   
     
     $response = Invoke-RestMethod -Method Get -Uri $url -Credential $cred -Body $body -TimeoutSec 300
     return $response
 }
 
 
# collect credentials from user, securely, at runtime
if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "admin" }
 
# define the splunk search to execute
$theSearch = ' search index=_internal earliest=-1d@d | table _time index host source sourcetype _raw '

# initiate the job
write-host (get-date) "- Initiating search job with search text [$($theSearch)]."

$searchjob = create-searchjob -server $server -port $port -cred $cred -search $theSearch
 
# Wait for the job to complete
$counter = 0
do
{
    # sleep 
    $counter++
    Start-Sleep -Seconds 1

    # get the job status object
    $jobstatus = check-searchjobstatus -server $server -port $port -cred $cred -jobsid $searchjob.response.sid
 
    # retrieve the dispatchState property (Can be any of QUEUED, PARSING, RUNNING, PAUSED, FINALIZING, FAILED, DONE)
    $dispatchState = [string]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "dispatchState"})."#text"

    # show status of the job
    write-host (get-date) "- Current dispatch sid $($searchjob.response.sid) has status [$($dispatchState)]."     
}
until ($dispatchState -match "(FAILED|DONE)")

if ($dispatchState -match "FAILED") {
    write-host (get-date) "- Job execution failed. Exiting."
} else {

    # now that the job is DONE, retrieve other job properties of interest:
    $jobSid = [string]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "sid"})."#text"
    $jobEventCount = [int]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "eventCount"})."#text"
    $jobResultCount = [int]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "resultCount"})."#text"
    $jobResultDiskUsage = [int]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "diskUsage"})."#text"
    $jobResultrunDuration = [float]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "runDuration"})."#text"
    $jobttl = [int]($jobstatus.entry.content.dict.key | ?{$_.Name -eq "ttl"})."#text"

    write-host (get-date) "- Job completed with EventCount=$($jobEventCount) ResultCount=$($jobResultCount) DiskUsage=$($jobResultDiskUsage) RunDuration=$($jobResultrunDuration) ttl=$($jobttl)"

    <#
    # now we have to retrieve the job results. Since this is REST, there are limits (default 50,000) [$maxResultRowsLimit] to count of records that can be returned.
    # https://answers.splunk.com/answers/25411/upper-limit-for-rest-api-limits-conf-maxresultrows.html
    #>
   
    $totalResultsExpected = ($jobEventCount + $jobResultCount)
    $totalResultsReturned = 0
    $jobResults = @()

    # create a tmp file to append results to (better than appending an object in memory)
    $tmpString = Get-Random -Minimum 10000 -Maximum 99999
    $tmpFileName = "SplunkSearchResultsTemp$($tmpString).csv"
    $tmpFilePath = $env:temp
    if (Test-Path -Path "$($tmpFilePath)\$($tmpFileName)") { Remove-Item -Path "$($tmpFilePath)\$($tmpFileName)" -Force }
    
    $downloadPart = 1
    do
    {
        # download the data in batches       
        $downloadPartFile = "$($tmpFilePath)\$($tmpFileName).part$($downloadPart)"
        write-host (get-date) "- Downloading up to $($maxResultRowsLimit) rows offset from $($totalResultsReturned) to $($downloadPartFile)"
        $jobresults = get-searchjob -server $server -port $port -cred $cred -jobsid $searchjob.response.sid -offset $totalResultsReturned

        $jobresults | ConvertFrom-Csv | Export-Csv -NoTypeInformation -Path $downloadPartFile
    
        $totalResultsReturned += $maxResultRowsLimit
        $downloadPart += 1
    
    }
    until ($totalResultsReturned -ge $totalResultsExpected)

    # now we need to coalesce the download parts
    $PartFiles = Get-ChildItem -Path $tmpFilePath -Filter "$($tmpFileName).part*" | Sort-Object -Property LastWriteTime

    foreach ($partfile in $partfiles) {

        write-host (get-date) "- Collating $($partfile.name) into $($tmpFileName)."

        # commit partfile 1 in it's entirety
        if ($partfile.name -match "\.part1$") {

            $partfile.FullName | Rename-Item -NewName "$($tmpFilePath)\$($tmpFileName)"
        } else {
            # commit all but line 1 in other partfiles
            $skip = 1

            # create the FileStream and StreamWriter objects
            $ins = New-Object System.IO.StreamReader($partfile.FullName)
            $fs = New-Object IO.FileStream "$($tmpFilePath)\$($tmpFileName)" ,'Append','Write','Read'
            $outs = New-Object System.IO.StreamWriter($fs)

            try {
                # Skip the first N lines, but allow for fewer than N, as well
                for( $s = 1; $s -le $skip -and !$ins.EndOfStream; $s++ ) {
                    # waste the top line
                    $ins.ReadLine() | Out-Null
                }
                while( !$ins.EndOfStream ) {
                    $outs.writeline( $ins.ReadLine() )
                }
            }
            finally {
            $outs.Close()
            $ins.close()
            $fs.Dispose()
            }
        }
        $partfile | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    write-host (get-date) "- Operation complete.  Result file is $($tmpFilePath)\$($tmpFileName)"

}
