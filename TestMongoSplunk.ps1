<#
TODO:  
https://dev.splunk.com/enterprise/docs/developapps/manageknowledge/kvstore/usetherestapitomanagekv/
Changes:
2022-08-13 DES
- Considered need for CRUD as part of .\CollectionInventory project
- Imported framework to interact with a MongoDB instance
#>

$splunk_rest_base_url = "https://win-9iksdb1vgmj.mshome.net:8089"

function get-splunksesionkey
{
    param($splunk_rest_base_url, $credential)

    $body = @{
        username = $Credential.username
        password = $Credential.GetNetworkCredential().Password;
    }

    $Response = Invoke-RestMethod -Uri "$($splunk_rest_base_url)/services/auth/login" -Body $body -SkipCertificateCheck -ContentType 'application/x-www-form-urlencoded' -Method Post
    $sessionKey = $Response.response.sessionKey
    return $sessionKey
}

# collect credentials from user, securely, at runtime
if (-not($credential)) { $Credential = $host.ui.PromptForCredential("Authenticate to Splunk service on $($splunk_rest_base_url)","Please enter your user name and password.","","") }

# get session keyt from credentials
$sessionKey = get-splunksesionkey -splunk_rest_base_url $splunk_rest_base_url -credential $Credential

$app_name = "search"
$collection_name = "mycollection2"

# | makeresults | eval name="David", message="Hello World" | outputlookup mycollection3


<############################################################
# list collections in the app
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
    'Content-Type' = 'application/json'    
    output_mode = "json"    
}
try {
    $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method get 
} catch { $_.Exception }
$WebRequest.Content   # what is this fucking garbage?


<############################################################
# create the collection (kvstore)
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
}
$body = @{
    name = $collection_name
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method Post
} catch { $_.Exception ; break }
$WebRequest.StatusDescription


<############################################################
# define the collection schema
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config/$($collection_name)"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
}
$body = @{
    'field.id' = 'number'
    'field.name' = 'string'
    'field.message' = 'string'        
    'accelerated_fields.my_accel' = '{"id": 1}'
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
} catch { $_.Exception ; break }
$WebRequest.StatusDescription


<############################################################
# create a lookup definition that corresponds to the collection
#  -- sadly this can only be perfomed locally on server
############################################################>
<#
$uri = "$($splunk_rest_base_url)/servicesNS/admin/$($app_name)/data/transforms/lookups"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
}
$body = @{
    'fields_list' = '_key, id, name, message'
    'type' = 'extenal'
    'external_type' = 'kvstore'
    'name' = $collection_name
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
} catch { $_.Exception ; break }
$WebRequest.StatusDescription
#>


<############################################################
# add an item to the collection
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
    'Content-Type' = 'application/json'
}
$body = @{
    name = "David"
    message = "Hello World!"
} | ConvertTo-Json -Compress
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
} catch { $_.Exception ; break }
$WebRequest.Content


<############################################################
# list items in the collection
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
    output_mode = "json"
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers
} catch { $_.Exception ; break }
($WebRequest.Content | ConvertFrom-Json).count


<############################################################
# update that motherfuckin' collection with a lot of shit
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)/batch_save"
$counter = 0
$headers = @{
    Authorization = "Splunk $($sessionKey)"
    'Content-Type' = 'application/json'
}

# put a bunch of records into body
$records = New-Object System.Collections.ArrayList
for ($i = 0; $i -le 500; $i++) {
    $counter++
    $record = [ordered]@{
        name = "David $($counter)"
        message = "Hello World $($counter)"
    }
    $records.add([pscustomobject]$record) | out-null
}
$body = $records | ConvertTo-Json -Compress
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
} catch { $_.Exception ; break }
$WebRequest.Content


<############################################################
# delete items in the collection
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
} catch { $_.Exception ; break }
$WebRequest


<############################################################
# delete the collection
############################################################>
$uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config/$($collection_name)"
$headers = @{
    Authorization = "Splunk $($sessionKey)"
}
try {
$WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
} catch { $_.Exception ; break }
$WebRequest

