function Create-IndexAccess-Role {
    # Note:  You can use the REST API to POST objects remotely, but not DELETE
    # http://docs.splunk.com/Documentation/Splunk/6.6.2/RESTREF/RESTaccess#authentication.2Fusers
    param ($cred, $server, $port, $name, $srchIndexesAllowed, $srchIndexesDefault)

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $url = "https://${server}:${port}/services/authorization/roles"
    $body = @{
        name = $name
        srchIndexesAllowed = $srchIndexesAllowed
        srchIndexesDefault = $srchIndexesDefault
    }
    
    $Response = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300
    return $Response
}

function Delete-IndexAccess-Role {
    # Note:  You can use the REST API to POST objects remotely, but not DELETE
    param ($cred, $server, $port, $name)

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $url = "https://${server}:${port}/services/authorization/roles/$($name)"
  
    Try {
        $Response = Invoke-RestMethod -Method Delete -Uri $url -Credential $cred -Body $body -TimeoutSec 300
    }
    catch {
        "item not found"
    }

    return $Response
}

function get-search-results {

    param ($cred, $server, $port, $search)

    # This will allow for self-signed SSL certs to work
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   #(ssl3,SystemDefault,Tls,Tls11,Tls12)

    $url = "https://${server}:${port}/services/search/jobs/export" 
    $the_search = "$($search)" # Cmdlet handles urlencoding
    $body = @{
        search = $the_search
        output_mode = "csv"
          }
    
    $SearchResults = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body -TimeoutSec 300
    if ($SearchResults) { $SearchResults = ConvertFrom-Csv -InputObject $SearchResults }

    return $SearchResults
}

$server = "127.0.0.1"
$port = "8089"

if (!($cred)) { $cred = Get-Credential -Message "enter splunk cred" -UserName "davides-adm" }

$idxroles= "C:\LocalApps\SplunkRoleMan\idx-roles.txt"
$idxroles = Import-Csv $idxroles

foreach ($role in $idxroles) {
    $Response = Delete-IndexAccess-Role -server $server -port $port -cred $cred -name $role.name
    $Response = Create-IndexAccess-Role -server $server -port $port -cred $cred -name $role.name -srchIndexesAllowed $role.srchIndexesAllowed -srchIndexesDefault $role.srchIndexesDefault
}

$searchresults = get-search-results -server $server -port $port -cred $cred -search "`|  rest /services/authorization/roles `|  search title=azure* `|  table author, title, id, srchIndexesAllowed, srchIndexesDefault"
$searchresults 


