<#
PURPOSE:
- Provide functions which support Splunk KVStore operations via REST
- https://dev.splunk.com/enterprise/docs/developapps/manageknowledge/kvstore/usetherestapitomanagekv/

TODO:
- Extend implementation of advanced functions through and comment-based help
- Improve error handling among functions
- Once and for all determine if it is possible to create transforms remotely as part of Add-KVStoreTransform function
- Improve handling of output from Get-KVStoreCollectionList
- Improve handling of failure conditions associated with credential gathering and Get-SplunkSessionKey



CHANGES:
- 2022-08-15 DES
    - Initial functionality
- 2022-08-16 DES
    - Conform function names to PowerShell Noun-Verb format
    - Conform function parameter names to Pascal case format
    - Enable advanced functions through cmdletbinding, parameter validation, error handling, and verbose output
    - Credit:  https://docs.microsoft.com/en-us/powershell/scripting/learn/ps101/09-functions?view=powershell-7.2
#>

$PoshVersionMinimum = [version]'7.0'
if ($PSVersionTable.PSVersion -le $PoshVersionMinimum)
{ throw "This script requires interpretation of PowerShell version $($PoshVersionMinimum) or higher"}

function Get-SplunkSessionKey
{   
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        $Credential
    )

    write-host "$(get-date) - Attempting to exchnage Splunk credential for web session key."

    $body = @{
        username = $Credential.username
        password = $Credential.GetNetworkCredential().Password;
    }

    try
    {
        $WebRequest = Invoke-RestMethod -Uri "$($BaseUrl)/services/auth/login" -Body $body -SkipCertificateCheck -ContentType 'application/x-www-form-urlencoded' -Method Post
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest.response.sessionKey
}
function Get-KVStoreCollectionList
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search"
    )

    Write-Verbose -Message "$(get-date) - getting KVstore collection list within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
        'Content-Type' = 'application/json'    
        output_mode = 'json'
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method GET
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest 
}
function Add-KVStoreCollection
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName
    )

    write-verbose -Message "$(get-date) - creating KVstore collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
    }

    $body = @{
        name = $CollectionName
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -body $body -Method Post
    } 
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest
}
function Set-KVStoreSchema
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName,
        [System.Collections.Hashtable[]]$CollectionSchema
    )

    write-verbose -Message "$(get-date) - setting schema for KVstore collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    <# Example CollectionSchema
        @{
            'field.id' = 'number'
            'field.name' = 'string'
            'field.message' = 'string'
            'accelerated_fields.my_accel' = '{"id": 1}'
        }
    #>

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config/$($CollectionName)"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
    }

    $body = $CollectionSchema

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest
}
function Add-KVStoreTransform
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName,
        [System.Collections.Hashtable[]]$TransformSchema
    )    

    Write-Verbose -Message "$(get-date) - adding transform for KVstore collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    <# Example TransformSchema:
        @{
            'fields_list' = '_key, id, name, message'
            'type' = 'extenal'
            'external_type' = 'kvstore'
            'name' = $CollectionName
        }
    #>

    $uri = "$($BaseUrl)/servicesNS/admin/$($AppName)/data/transforms/lookups"
    
    $headers = @{
        Authorization = "Splunk $($SessionKey)"
    }

    $body = $TransformSchema

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest 
}
function Add-KVStoreRecord
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName,
        [System.Management.Automation.PSCustomObject[]]$Record
    )

    Write-Verbose -Message "$(get-date) - adding single record to collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    <# Example Record:
        @{
            name = "David"
            message = "Hello World!"
        }
    #>

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
        'Content-Type' = 'application/json'
    }

    $body = $Record | ConvertTo-Json -Compress

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest 
}
function Get-KVStoreRecords
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - retrieving records from collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
        output_mode = 'json'
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers
    } 
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest 
}
function Add-KVStoreRecordBatch
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName,
        [System.Management.Automation.PSCustomObject[]]$Records
    )

    Write-Verbose -Message "$(get-date) - adding array of records in collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)/batch_save"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
        'Content-Type' = 'application/json'
    }
    
    $body = $Records | ConvertTo-Json -Compress

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Post
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest
}
function Remove-KVStoreRecords
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - removing records in collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest 
}
function Remove-KVStoreCollection
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string[]]$SessionKey,
        [Parameter(Mandatory)]
        [string[]]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string[]]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - removing collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config/$($CollectionName)"

    $headers = @{
        Authorization = "Splunk $($SessionKey)"
    }

    try
    {
        $WebRequest = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Headers $headers -Body $body -Method Delete
    }
    catch
    {
        Write-Warning -Message "An exception occured with text: $($_.Exception)"
        return $WebRequest
    }

    return $WebRequest    
}

$splunk_server = 'win-9iksdb1vgmj.mshome.net'
$splunk_rest_port = '8089'
$BaseUrl = "https://$($splunk_server):$($splunk_rest_port)"

$AppName = 'search'
$CollectionName = "test_collection_$($env:USERNAME)_2"

$CollectionSchema = @{
    'field.id' = 'number'
    'field.name' = 'string'
    'field.message' = 'string'
    'accelerated_fields.my_accel' = '{"id": 1}'
}

$TransformSchema = @{
    'fields_list' = '_key, id, name, message'
    'type' = 'extenal'
    'external_type' = 'kvstore'
    'name' = $CollectionName
}

$Records = New-Object System.Collections.ArrayList
for ($i = 0; $i -le 10; $i++) {
    $Record = [ordered]@{
        name = "$($env:USERNAME)-$($i)"
        message = "Hello World $($i)!"
    }
    $Records.add([pscustomobject]$Record) | out-null
}

<#############################################################
## MAIN
##############################################################>

# collect credentials from user, securely, at runtime
if (-not($credential)) { $Credential = $host.ui.PromptForCredential("Authenticate to Splunk service on $($BaseUrl)","Please enter your user name and password.","","") }


# get session key from credential based authentication
if (-not($SessionKey)) { $SessionKey = Get-SplunkSessionKey -BaseUrl $BaseUrl -credential $Credential }


# get list of kvstore collections in specified app (todo - not fully implemented)
# $webrequest = Get-KVStoreCollectionList -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName


# create kvstore collection in specified app
$webrequest = Add-KVStoreCollection -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName -Verbose
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }


# set kvstore collection schema
$webrequest = Set-KVStoreSchema -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName -CollectionSchema $CollectionSchema
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }


# add kvstore record in specified collection in specified app
$webrequest = Add-KVStoreRecord -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName -Record $Records[0]
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }
$webrequest.content

# get kvstore records in specified collection in specified app
$webrequest = Get-KVStoreRecords -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }
$webrequest.Content | ConvertFrom-Json


# add kvstore records in specified collection in specified app
$webrequest = Add-KVStoreRecordBatch -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName -Records $Records
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }
$webrequest.content

# remove kvstore records in specified collection in specified app
$webrequest = Remove-KVStoreRecords -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }

# remove kvstore collection in specified app
$webrequest = Remove-KVStoreCollection -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }
