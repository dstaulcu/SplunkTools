# https://docs.splunk.com/Documentation/Splunk/7.2.6/RESTTUT/RESTsearches
 
 function create-searchjob {
 
 
     param ($cred, $server, $port, $search)
 
     # This will allow for self-signed SSL certs to work
     [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)
 
     $url = "https://${server}:${port}/services/search/jobs" # braces needed b/c the colon is otherwise a scope operator
     $the_search = "$($search)" # Cmdlet handles urlencoding
     $body = @{
         search = $the_search
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
     $response = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -TimeoutSec 300
     return $response
 }
 
 function get-searchjob {
 
 
     param ($cred, $server, $port, $jobsid)
 
     # This will allow for self-signed SSL certs to work
     [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)
 
     $url = "https://${server}:${port}/services/search/jobs/$($jobsid)/results/" 
     $body = @{
         output_mode = "csv"
           }   
     
     $response = Invoke-RestMethod -Method Get -Uri $url -Credential $cred -Body $body -TimeoutSec 300
     return $response
 }
 
 
 
# define splunk instance variables to use
$server = "splunk-dev"
$port = "8089"
 
# collect credentials from user, securely, at runtime
if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "admin" }
 
# define the splunk search to execute
$theSearch = '| rest /services/data/transforms/lookups 
| regex type="(kvstore|file|geo|external)" 
| eval object=case(type=="kvstore",collection,type=="external",external_cmd,type=="file",filename,type=="geo",filename,1==1,"Unknown") 
| eval marker = $eai:acl.app$ + "|" + $eai:acl.sharing$ + "|" + title 
| table eai:acl.app, eai:acl.sharing, eai:acl.perms.read, title, type, object, author, eai:acl.owner, id, marker 
| join type=left marker 
    [| rest /services/data/props/lookups 
    | eval marker = $eai:acl.app$ + "|" + $eai:acl.sharing$ + "|" + transform 
    | rename id as AutoLookup 
    | table marker, AutoLookup]
|  eval AutoLookup=if(isnull(AutoLookup),"FALSE","TRUE")
| table eai:acl.app, eai:acl.sharing, eai:acl.perms.read, title, type, object, AutoLookup, author, eai:acl.owner, id, marker
| sort 0 eai:acl.app, eai:acl.sharing, title'
 
# initiate the job
$results_1 = create-searchjob -server $server -port $port -cred $cred -search $theSearch
 
# check status of job on interval
$counter = 0
do
{
    # sleep 
    $counter++
    Start-Sleep -Seconds 1
  
    $jobstatus = check-searchjobstatus -server $server -port $port -cred $cred -jobsid $results_1.response.sid
 
    #The state of the search. Can be any of QUEUED, PARSING, RUNNING, PAUSED, FINALIZING, FAILED, DONE.
    $dispatchState = ($jobstatus.entry.content.dict.key | ?{$_.Name -eq "dispatchState"})."#text"
    write-host (get-date) " - Current dispatch status is [$($dispatchState)]."
     
}
until ($dispatchState -match "(FAILED|DONE)")

# assuming successful completion, get results as CSV into PoshObject
$results_1 = get-searchjob -server $server -port $port -cred $cred -jobsid $results_1.response.sid
$results_1 = ConvertFrom-Csv -InputObject $results_1

# filter results to only include lookup objects of type file and keystore
$results_1 = $results_1 | ?{$_.type -match "(file|kvstore)"}

# initialize the array of finalized results
$recordSet = @()

# Get the size and rowcount of each object
foreach ($result_1 in $results_1) {
    # define the splunk search to execute
    $theSearch = "| inputlookup $($result_1.title)"

    write-host (get-date) " - Invoking search [$($theSearch)]."
 
    # initiate the job
    $results_2 = create-searchjob -server $server -port $port -cred $cred -search $theSearch
 
    # check status of job on interval
    $counter = 0
    do
    {
        # sleep 
        $counter++
        Start-Sleep -Seconds 1
  
        $jobstatus = check-searchjobstatus -server $server -port $port -cred $cred -jobsid $results_2.response.sid
 
        #The state of the search. Can be any of QUEUED, PARSING, RUNNING, PAUSED, FINALIZING, FAILED, DONE.
        $dispatchState = ($jobstatus.entry.content.dict.key | ?{$_.Name -eq "dispatchState"})."#text"
        write-host (get-date) " - Current dispatch status is [$($dispatchState)]."
     
    }
    until ($dispatchState -match "(FAILED|DONE)")

    # assuming successful completion, get results as CSV into PoshObject
    $results_2 = get-searchjob -server $server -port $port -cred $cred -jobsid $results_2.response.sid
    $results_2 = ConvertFrom-Csv -InputObject $results_2

    # get the count of records
    $recordCount = if($results_2) { $results_2.count } else { 0 }

    # get the size of the object
    if ($results_2) {
        $randString = Get-Random -Minimum 10000 -Maximum 99999
        $tmpfile = "$env:TEMP\spltmp$($randString)"
        if (Test-Path -Path $tmpfile) { Remove-Item -Path $tmpfile -Force }
        $results_2 | Export-Csv -NoTypeInformation -Path $tmpfile
        $tmpFileInfo = Get-Item -Path $tmpfile
        $recordSetHash = (Get-FileHash -Path $tmpfile -Algorithm MD5).hash
        $recordSetSize = $tmpFileInfo.length
        if (Test-Path -Path $tmpfile) { Remove-Item -Path $tmpfile -Force }   
    } else {
        $recordSetSize = 0
        $recordSetHash = 0
    }

    $info = @{
        "eai:acl.app" = $result_1.'eai:acl.app'
        "eai:acl.sharing" = $result_1.'eai:acl.sharing'
        "eai:acl.perms.read" = $result_1.'eai:acl.perms.read'
        "title" = $result_1.title
        "type" = $result_1.type
        "AutoLookup" = $result_1.AutoLookup
        "object" = $result_1.object
        "author" = $result_1.author
        "eai:acl.owner" = $result_1.'eai:acl.owner'
        "id" = $result_1.id
        "marker" = $result_1.marker
        "recordCount" = $recordCount
        "recordSetSize" = $recordSetSize                                         
        "recordSetHash" = $recordSetHash
    }

    $recordSet += New-Object -TypeName PSObject -Property $info
    
}

$recordSet | Select-Object -Property eai:acl.app, eai:acl.sharing, eai:acl.perms.read, title, type, AutoLookup, object, recordCount, recordSetSize, recordSetHash, author, eai:acl.owner, id, marker | Sort-Object -Property RecordSetSize -Descending | Out-GridView -Title "Lookup Info"









