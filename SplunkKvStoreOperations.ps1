<#
PURPOSE:
- Provide functions which support Splunk KVStore operations via REST
- https://dev.splunk.com/enterprise/docs/developapps/manageknowledge/kvstore/usetherestapitomanagekv/

TODO:
- Determine if it posible to create transform remotely
- Improve handling of output from get-kvstorecollectionlist
- Improve error handling among functions

CHANGES:
- 2022-08-15 DES
    - Initial functionality
#>

$PoshVersionMinimum = [version]'7.0'
if ($PSVersionTable.PSVersion -le $PoshVersionMinimum)
{ throw "This script requires interpretation of PowerShell version $($PoshVersionMinimum) or higher"}

$splunk_server = 'win-9iksdb1vgmj.mshome.net'
$splunk_rest_port = '8089'
$splunk_rest_base_url = "https://$($splunk_server):$($splunk_rest_port)"

$app_name = 'search'
$collection_name = "test_collection_$($env:USERNAME)"

$schema_collection = @{
    'field.id' = 'number'
    'field.name' = 'string'
    'field.message' = 'string'
    'accelerated_fields.my_accel' = '{"id": 1}'
}

$schema_transform = @{
    'fields_list' = '_key, id, name, message'
    'type' = 'extenal'
    'external_type' = 'kvstore'
    'name' = $collection_name
}

$records = New-Object System.Collections.ArrayList
for ($i = 0; $i -le 10; $i++) {
    $record = [ordered]@{
        name = "$($env:USERNAME)-$($i)"
        message = "Hello World $($i)!"
    }
    $records.add([pscustomobject]$record) | out-null
}

function get-splunksesionkey
{   
    param($splunk_rest_base_url, $credential)

    write-host "$(get-date) - Attempting to exchnage Splunk credential for web session key."

    $body = @{
        username = $Credential.username
        password = $Credential.GetNetworkCredential().Password;
    }

    try
    {
        $WebRequest = Invoke-RestMethod -Uri "$($splunk_rest_base_url)/services/auth/login" -Body $body -SkipCertificateCheck -ContentType 'application/x-www-form-urlencoded' -Method Post
    }
    catch
    {
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
        return $WebRequest
    }

    return $WebRequest.response.sessionKey
}
function get-kvstorecollectionlist
{
    param($splunk_rest_base_url, $sessionKey, $app_name)

    write-host "$(get-date) - getting KVstore collection list within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
        'Content-Type' = 'application/json'    
        output_mode = 'json'
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method GET
    }
    catch
    {
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest 
}
function add-kvstorecollection
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name)

    write-host "$(get-date) - creating KVstore collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
    }

    $body = @{
        name = $collection_name
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method Post
    } 
    catch
    { 
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest
}
function set-kvstorecollectionschema
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name, $schema_collection)

    <# Example Schema
        @{
            'field.id' = 'number'
            'field.name' = 'string'
            'field.message' = 'string'
            'accelerated_fields.my_accel' = '{"id": 1}'
        }
    #>

    write-host "$(get-date) - setting schema for KVstore collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config/$($collection_name)"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
    }

    $body = $schema_collection

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    { 
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception 
    }

    return $WebRequest
}
function add-splunkkvtransform
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name, $schema_transform)

    write-host "$(get-date) - adding transform for KVstore collection named `"$($collection_name)`" within `"$($app_name)`" app."

    <# Example schema_transform:
        @{
            'fields_list' = '_key, id, name, message'
            'type' = 'extenal'
            'external_type' = 'kvstore'
            'name' = $collection_name
        }
    #>

    $uri = "$($splunk_rest_base_url)/servicesNS/admin/$($app_name)/data/transforms/lookups"
    
    $headers = @{
        Authorization = "Splunk $($sessionKey)"
    }

    $body = $schema_transform

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception 
    }

    return $WebRequest 
}
function add-kvstorecollectionrecord
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name, $record)

    write-host "$(get-date) - adding single record to collection named `"$($collection_name)`" within `"$($app_name)`" app."

    <# Example record:
        @{
            name = "David"
            message = "Hello World!"
        }
    #>

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
        'Content-Type' = 'application/json'
    }

    $body = $record | ConvertTo-Json -Compress

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest 
}
function get-kvstorecollectionrecords
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name, $record)

    write-host "$(get-date) - retrieving records from collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
        output_mode = 'json'
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers
    } 
    catch
    {
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest 
}
function add-kvstorecollectionrecordarray
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name, $records)

    write-host "$(get-date) - adding array of records in collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)/batch_save"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
        'Content-Type' = 'application/json'
    }
    
    $body = $records | ConvertTo-Json -Compress

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    { 
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest
}
function remove-kvstorecollectionrecords
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name)

    write-host "$(get-date) - removing records in collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/data/$($collection_name)"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
    }
    catch
    { 
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception
    }

    return $WebRequest 
}
function remove-kvstorecollection
{
    param($splunk_rest_base_url, $sessionKey, $app_name, $collection_name)

    write-host "$(get-date) - removing collection named `"$($collection_name)`" within `"$($app_name)`" app."

    $uri = "$($splunk_rest_base_url)/servicesNS/nobody/$($app_name)/storage/collections/config/$($collection_name)"

    $headers = @{
        Authorization = "Splunk $($sessionKey)"
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
    }
    catch
    { 
        write-host "$(get-date) - An exception occured." -ForegroundColor Red
        $_.Exception 
    }

    return $WebRequest    
}

# collect credentials from user, securely, at runtime
if (-not($credential)) { $Credential = $host.ui.PromptForCredential("Authenticate to Splunk service on $($splunk_rest_base_url)","Please enter your user name and password.","","") }

# get session key from credential based authentication
if (-not($sessionKey)) { $sessionKey = get-splunksesionkey -splunk_rest_base_url $splunk_rest_base_url -credential $Credential }

# get list of kvstore collections in specified app
$webrequest = get-kvstorecollectionlist -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name

# create kvstore collection in specified app
$webrequest = add-kvstorecollection -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }

# set kvstore collection schema
$webrequest = set-kvstorecollectionschema -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name -schema_collection $schema_collection
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }

# add kvstore record in specified collection in specified app
$webrequest = add-kvstorecollectionrecord -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name -record $records[0]
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }
$webrequest.content

# get kvstore records in specified collection in specified app
$webrequest = get-kvstorecollectionrecords -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }
$webrequest.Content | ConvertFrom-Json

# add kvstore records in specified collection in specified app
$webrequest = add-kvstorecollectionrecordarray -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name -records $records
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }
$webrequest.content

# remove kvstore records in specified collection in specified app
$webrequest = remove-kvstorecollectionrecords -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }

# remove kvstore collection in specified app
$webrequest = remove-kvstorecollection -splunk_rest_base_url $splunk_rest_base_url -sessionKey $sessionKey -app_name $app_name -collection_name $collection_name
if ($Webrequest.StatusCode -notmatch "^2\d{2}$") { break }
