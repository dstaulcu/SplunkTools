<#
PURPOSE:
- Provide functions which support Splunk KVStore operations via REST
- https://dev.splunk.com/enterprise/docs/developapps/manageknowledge/kvstore/usetherestapitomanagekv/

TODO:
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
    - Enable advanced functions through cmdletbinding, parameter validation, error handling, verbose output, and comment-based help
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
<#
.SYNOPSIS
    Returns a list of KVstore collections registered in Splunk.

.DESCRIPTION
    Get-KVStoreCollectionList is a function that returns a list of Returns a list of KVstore
    collections registered in Splunk.

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    are associated with.

.EXAMPLE
     Get-KVStoreCollectionList -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search'
#>

    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search"
    )

    Write-Verbose -Message "$(get-date) - getting KVstore collection list within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config"

    $headers = [ordered]@{
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

function Add-KVStoreTransform
{
<#
.SYNOPSIS
    Add a KVstore transform entry (lookup) to a specified app in Splunk.

.DESCRIPTION
    Add a KVstore transform entry (lookup) to a specified app in Splunk.

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection that will registered

.PARAMETER TransformSchema
    A hash table with values for fields_list, type, external_type and name.

.EXAMPLE
     Add-KVStoreTransform -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test' -TransformSchema @{
            'fields_list' = '_key, id, name, message'
            'type' = 'extenal'
            'external_type' = 'kvstore'
            'name' = 'test'
        }
#>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,
        $TransformSchema
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
    
    $headers = [ordered]@{
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
<#
.SYNOPSIS
    Add a single record into kvstore collection

.DESCRIPTION
    Add a single record into kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection that will registered

.PARAMETER Record
    A hash table with values for fields_list entities

.EXAMPLE
     Add-KVStoreRecord -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test' -Record @{
            name='David''
            message = 'Hello world!'
        }
#>

    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,
        $Record
    )

    Write-Verbose -Message "$(get-date) - adding single record to collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = [ordered]@{
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
    <#
.SYNOPSIS
    List records in a specified kvstore collection

.DESCRIPTION
    List records in a specified kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection that will registered

.PARAMETER Records
    A hash table with values for fields_list entities

.EXAMPLE
     Get-KVStoreRecords -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test'
#>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - retrieving records from collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = [ordered]@{
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
<#
.SYNOPSIS
    Add a single record into kvstore collection

.DESCRIPTION
    Add a single record into kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection that will registered

.PARAMETER Record
    A hash table with values for fields_list entities

.EXAMPLE
     Add-KVStoreRecordBatch -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test' -Record $Records
#>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,
        $Records
    )

    Write-Verbose -Message "$(get-date) - adding array of records in collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)/batch_save"

    $headers = [ordered]@{
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
<#
.SYNOPSIS
    Remove records in a kvstore collection

.DESCRIPTION
    Remove records in a kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection

.EXAMPLE
     Remove-KVStoreRecords -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test'
#>    
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - removing records in collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/data/$($CollectionName)"

    $headers = [ordered]@{
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
<#
.SYNOPSIS
    Remove a kvstore collection

.DESCRIPTION
    Remove a kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection

.EXAMPLE
     Remove-KVStoreCollection -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test'
#> 
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName
    )

    Write-Verbose -Message "$(get-date) - removing collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config/$($CollectionName)"

    $headers = [ordered]@{
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

function Add-KVStoreCollection
{
<#
.SYNOPSIS
    Add a kvstore collection

.DESCRIPTION
    Add a kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection

.EXAMPLE
     Add-KVStoreCollection -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test'
#> 
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [string]$CollectionName
    )

    $ProgressPreference = 'SilentlyContinue'

    write-verbose -Message "$(get-date) - creating KVstore collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config"

    $headers = [ordered]@{
        Authorization = "Splunk $($sessionKey)"
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    $body = @{
        name = $CollectionName
    } 

    write-verbose -Message "$(get-date) - invoking webrequest to url $($uri) with header of $($headers) and body of $($body)"    

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

function Set-KVStoreSchema
{
<#
.SYNOPSIS
    Set the schema associated with a kvstore collection

.DESCRIPTION
    Set the schema associated with a kvstore collection

.PARAMETER BaseUrl
    A string representing a url path to the management interface of a Spunk server.
    The string is constructed with https://<hostname>:<port>
    The default port is 8089.

.PARAMETER SessionKey
    A session key composed from output of the Get-SplunkSessionKey function

.PARAMETER AppName
    The name of the splunk app (search, home, etc.) that the KVStore of interest
    is associated with.

.PARAMETER CollectionName
    The name of the kvstore collection

.PARAMETER CollectionSchema
    A hash containing desired elements of collection schema.  See example.

.EXAMPLE
     Set-KVStoreSchema -BaseURL 'https://mysplunk:8089' -SessionKey 'Splunk asdfAasdfasdfasdfasdf....' -AppName 'search' -CollectionName 'test' -CollectionSchema  @{
            'field.id' = 'number'
            'field.name' = 'string'
            'field.message' = 'string'
            'accelerated_fields.my_accel' = '{"id": 1}'
        }
#> 
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        [ValidateNotNullOrEmpty()]
        [string]$SessionKey,
        [Parameter(Mandatory)]
        [string]$AppName="search",
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,
        $CollectionSchema
    )

    write-verbose -Message "$(get-date) - setting schema for KVstore collection named `"$($CollectionName)`" within `"$($AppName)`" app."

    $uri = "$($BaseUrl)/servicesNS/nobody/$($AppName)/storage/collections/config/$($CollectionName)"

    $headers = [ordered]@{
        Authorization = "Splunk $($SessionKey)"
        Accept = 'application/json'
        'Content-Type' = 'application/json'
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

$splunk_server = 'win-9iksdb1vgmj.mshome.net'
$splunk_rest_port = '8089'
$BaseUrl = "https://$($splunk_server):$($splunk_rest_port)"

$AppName = 'search'
$CollectionName = "test_collection_$($env:USERNAME)_3"

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

# collect credentials from user, securely, at runtime
if (-not($credential)) { $Credential = $host.ui.PromptForCredential("Authenticate to Splunk service on $($BaseUrl)","Please enter your user name and password.","","") }

# get session key from credential based authentication
$SessionKey = Get-SplunkSessionKey -BaseUrl $BaseUrl -credential $Credential 

# get list of kvstore collections in specified app (todo - not fully implemented)
$webrequest = Get-KVStoreCollectionList -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName "search"
if ($Webrequest.StatusCode -notmatch "^(200|201)$") { break }
$XmlContent = [xml]$webrequest.Content
$XmlContent.feed.entry.title

# create kvstore collection in specified app
$webrequest = Add-KVStoreCollection -BaseUrl $BaseUrl -SessionKey $SessionKey -AppName $AppName -CollectionName $CollectionName
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
