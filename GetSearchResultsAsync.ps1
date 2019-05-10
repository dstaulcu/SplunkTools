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
 $theSearch = 'search index=_internal earliest=-5m@m | stats count by sourcetype' 
 
 # initiate the job
 $results = create-searchjob -server $server -port $port -cred $cred -search $theSearch
 
 # check status of job on interval
 $counter = 0
 do
 {
     # sleep 
     $counter++
     Start-Sleep -Seconds 1
 
 
     $jobstatus = check-searchjobstatus -server $server -port $port -cred $cred -jobsid $results.response.sid
 
     #The state of the search. Can be any of QUEUED, PARSING, RUNNING, PAUSED, FINALIZING, FAILED, DONE.
     $dispatchState = ($jobstatus.entry.content.dict.key | ?{$_.Name -eq "dispatchState"})."#text"
     write-host (get-date) " - Current dispatch status is [$($dispatchState)]."
     
 }
until ($dispatchState -match "(FAILED|DONE)")

# assuming successful completion, get results as CSV into PoshObject
$results = get-searchjob -server $server -port $port -cred $cred -jobsid $results.response.sid
$results = ConvertFrom-Csv -InputObject $results
$results







