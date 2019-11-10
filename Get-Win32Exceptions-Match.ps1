
$tmpFile = "$($env:TEMP)\Win32ExceptionsList.csv"

$Messages = @()
$filter = "^DNS"

for ($i = 0; $i -lt 65500; $i++)
{ 
    $Message = [ComponentModel.Win32Exception] $i   
    if (($i -eq 0) -or ($Message.Message -match $filter)) {
        $Info = @{
            ErrorCode = $i
            Message = $Message.Message

        }
        $Messages += New-Object -TypeName PSObject -Property $Info
    }
}

$Selected = $Messages | Select-Object -Property ErrorCode, Message | Sort-Object ErrorCode| Out-GridView -PassThru -Title "Select a class of messages"

if ($Selected) {
    if (Test-Path -Path $tmpFile) { Remove-Item -Path $tmpFile -Force }
    $Selected | Export-Csv -Path $tmpFile -NoTypeInformation
    Write-Host "output written to $($tmpFile)."
    & notepad.exe $tmpFile
}

<# SPLUNK CASE STATEMENT CREATE

    $tmpFile2 = "$($env:TEMP)\SPLCaseCreate,txt"
    $statement = ""

    $Selected = $Selected | Sort-Object -Property ErrorCode
    foreach ($item in $Selected) {
        if ($statement -eq "") {
            $statement = "eval statement = case(QueryStatus==`"$($item.ErrorCode)`",`"$($item.Message)`""
        } else {
            $statement += ",QueryStatus==`"$($item.ErrorCode)`",`"$($item.Message)`""
        }
    }

    $statement += ",1==1,`"Unknown`")"
    $statement

    if (Test-Path -Path $tmpFile2) { Remove-Item -Path $tmpFile2 -Force }
    $statement | Add-Content -Path $tmpFile2 
    & notepad.exe $tmpFile2

#>