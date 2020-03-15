$services = @(
    "192.168.1.1:80:Home Router Web Interface",
    "192.168.1.1:81:Home Router Web Interface2"
    "127.0.0.1:8089:Local host Splunk admin port"    
)

function test-service {
    param ($ipaddress, $port)
    try {
        $connection = New-Object System.Net.Sockets.TcpClient($ipaddress, $port)
        if ($connection.Connected) {
            return $true
        } else {
            return $false
        }        
        $connection.Close()
    } catch {
        return $false
    }

}

$Results = @()
foreach ($service in $services) {

    $Server = ($service -split ":")[0].trim()
    $Port = ($service -split ":")[1].trim()
    $Description = ($service -split ":")[2].trim()

    $info = @{
        Server = $Server
        Port = $Port
        Description = $Description
        ConnectionSucceeded = test-service -ipaddress $server -port $Port
    }

    $Results += New-Object -TypeName PSObject -Property $Info
    
}

$Results | Select-Object -Property Server, Port, Description, ConnectionSucceeded | Sort-Object -Property Server, Port | Out-GridView -Title "Test Results"
