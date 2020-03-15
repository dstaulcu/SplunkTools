# tcp services to be tested
$services = @(
    "192.168.1.1:80:Home Router Web Interface",
    "192.168.1.1:81:Home Router Web Interface2"
    "127.0.0.1:8089:Local host Splunk admin port"    
)

# initialize output file
$outputFile = "$($env:temp)\test_connection_results.csv"
if (test-path -path $outputFile) { Remove-Item -Path $outputFile -Force}

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

# initialize array for results
$Results = @()

# test each of the services
foreach ($service in $services) {
    $Server = ($service -split ":")[0].trim()
    $Port = ($service -split ":")[1].trim()
    $Description = ($service -split ":")[2].trim()

    $test_time = Get-Date
    $info = @{
        Server = $Server
        Port = $Port
        Description = $Description
        TestStatus = test-service -ipaddress $server -port $Port
        TestDurationMs = (New-TimeSpan -Start $test_time).TotalMilliseconds
    }

    $Results += New-Object -TypeName PSObject -Property $Info    
}

# write results to results file
$Results | Export-Csv -NoTypeInformation -Path $outputFile
write-host "Results written to output file: $($outputfile)."

$outputFile | Import-Csv | select-object -property Server, Port, Description, TestStatus, TestDurationMs | Sort-Object Server, Port | Out-GridView -Title "Test results in output file $($outputfile)"

