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
$lookupRecords = @()

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
        $lookupRecordsHash = (Get-FileHash -Path $tmpfile -Algorithm MD5).hash
        $lookupRecordsSize = $tmpFileInfo.length
        if (Test-Path -Path $tmpfile) { Remove-Item -Path $tmpfile -Force }   
    } else {
        $lookupRecordsSize = 0
        $lookupRecordsHash = 0
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
        "recordSetSize" = $lookupRecordsSize                                         
        "recordSetHash" = $lookupRecordsHash
    }

    $lookupRecords += New-Object -TypeName PSObject -Property $info
    
}

#$lookupRecords | Select-Object -Property eai:acl.app, eai:acl.sharing, eai:acl.perms.read, title, type, AutoLookup, object, recordCount, recordSetSize, recordSetHash, author, eai:acl.owner, id, marker | Sort-Object -Property RecordSetSize -Descending | Out-GridView -Title "Lookup Info"


# get all of the lookups referenced in all of the savedsearches/dasboards
$theSearch = '| rest /servicesNS/-/-/data/ui/views splunk_server=local 
| rename eai:appName as appName, eai:acl.owner as owner, eai:acl.sharing as sharing, eai:data as data, eai:type as type 
| fields type, appName, sharing, owner, title, updated, data, id 
| append 
    [| rest/servicesNS/-/-/saved/searches splunk_server=local 
    | eval type="search" 
    | rename eai:acl.app as appName, eai:acl.owner as owner, qualifiedSearch as data 
    | fields type, appName, sharing, owner, title, updated, data, id
        ] 
| regex data="(?msi)\|\s*(input)?lookup\s+" 
| rex field=data "\|\s*(input)?lookup\s+(append=\S+\s+)?(start=\d+\s+)?(max=\d+\s+)?(local=\S+\s+)?(update=\S+\s+)?(?<lookup_name>[^\]\s|]+)" max_match=0 
| sort 0 appName, type, title
| mvexpand lookup_name
| regex lookup_name!="^(on|supports|whoisLookup|dnslookup)$"
| table type, lookup_name, appName, sharing, owner, title, updated, data, id'


write-host (get-date) " - Invoking search to retrieve lookup references in savedsearches/views."
 
# initiate the job
$results_3 = create-searchjob -server $server -port $port -cred $cred -search $theSearch
 
# check status of job on interval
$counter = 0
do
{
    # sleep 
    $counter++
    Start-Sleep -Seconds 1
  
    $jobstatus = check-searchjobstatus -server $server -port $port -cred $cred -jobsid $results_3.response.sid
 
    #The state of the search. Can be any of QUEUED, PARSING, RUNNING, PAUSED, FINALIZING, FAILED, DONE.
    $dispatchState = ($jobstatus.entry.content.dict.key | ?{$_.Name -eq "dispatchState"})."#text"
    write-host (get-date) " - Current dispatch status is [$($dispatchState)]."
     
}
until ($dispatchState -match "(FAILED|DONE)")

# assuming successful completion, get results as CSV into PoshObject
$results_3 = get-searchjob -server $server -port $port -cred $cred -jobsid $results_3.response.sid
$results_3 = ConvertFrom-Csv -InputObject $results_3

# check to see if there are references to broken lookups in savedsearches/views
$Findings = @()
foreach ($item in $results_3) {
    write-host "Checking lookup [$($item.lookup_name)] reference in $($item.id)."

    $MatchFound = $False
    $Staus = "WARN"
    $Message = ""

    foreach ($lookupRecord in $lookupRecords) {
        if ($item.lookup_name -match "^$($lookupRecord.title)$") {
            $MatchFound = $True
            if ($lookupRecord.recordCount -eq 0) {
                $Status = "WARN"
                $Message = "matching lookup has 0 records"
                write-host "`tWARNING: Found matching record but lookup has $($lookuprecord.recordCount) entries!" -ForegroundColor Red
            } else {
                $Status = "OK"
                $Message = "matching lookup has more than 0 records"
                write-host "`tFound matching record having $($lookuprecord.recordCount) entries." -ForegroundColor Green
            }

        }
    }
    if ($MatchFound -eq $False) {
        $Status = "WARN"
        $Message = "no matching lookup found"
        write-host "`tWARNING: Did not find a matching record.!" -ForegroundColor Red
    }

    $info = @{
        "type" = $item.type
        "lookup_name" = $item.lookup_name
        "appName" = $item.appName
        "sharing" = $item.sharing
        "owner" = $item.owner
        "title" = $item.title
        "updated" = $item.updated
        "data" = $item.data
        "id" = $item.id
        "status" = $Status
        "message" = $Message
    }

    $Findings += New-Object -TypeName PSObject -Property $info

}

$findings | Select-Object -Property appName, title, type, sharing, lookup_name, status, message, owner, updated, id, data | Sort-Object -Property appName, title, type | Out-GridView -Title "Findings"


# find lookups that are not referenced by any searches/views
$LookupReferences = $results_3 | Group-Object -Property lookup_name 
$lookupRecords2 = @()
foreach ($lookupRecord in $lookupRecords) {

    $MatchFound = $False
    foreach ($LookupReference in $LookupReferences) {
        if ($lookupRecord.title -eq $LookupReference.Name) {
            $MatchFound = $True
            $LookupReferenceCount = $LookupReference.Count
        }
    }
    if ($MatchFound -eq $False) {
            $LookupReferenceCount = 0
    }

    $info = @{
        "eai:acl.app" = $lookupRecord.'eai:acl.app'
        "eai:acl.sharing" = $lookupRecord.'eai:acl.sharing'
        "eai:acl.perms.read" = $lookupRecord.'eai:acl.perms.read'
        "title" = $lookupRecord.title
        "type" = $lookupRecord.type
        "AutoLookup" = $lookupRecord.AutoLookup
        "object" = $lookupRecord.object
        "author" = $lookupRecord.author
        "eai:acl.owner" = $lookupRecord.'eai:acl.owner'
        "id" = $lookupRecord.id
        "marker" = $lookupRecord.marker
        "recordCount" = $lookupRecord.recordCount
        "recordSetSize" = $lookupRecord.recordSetSize                                         
        "recordSetHash" = $lookupRecord.recordSetHash
        "referenceCount" = $LookupReferenceCount
    }

    $lookupRecords2 += New-Object -TypeName PSObject -Property $info
    
            
    write-host "Lookup record $($lookupRecord.title) was referenced $($LookupReferenceCount) times."
}

$lookupRecords2 | Select-Object -Property eai:acl.app, eai:acl.sharing, eai:acl.perms.read, title, type, AutoLookup, object, recordCount, recordSetSize, recordSetHash, referenceCount, author, eai:acl.owner, id, marker | Sort-Object -Property RecordSetSize -Descending | Out-GridView -Title "Lookup Info"