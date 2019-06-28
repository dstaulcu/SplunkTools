$file = "C:\dump.txt"
$content = Get-Content -Path $file

$newfile = $file -replace "\.","_masked."
if (Test-Path -Path $newfile) { Remove-Item $newfile -Force }

$newcontent = @()
foreach ($line in $content) {
#    if ($line -imatch "(DC=|CN=|\[|bindDNpassword = )") {
    if ($line -imatch "(DC=|CN=|bindDNpassword = )") {
        $newline = $line
        $newline = $newline -replace "DC=[^,]+","DC=XXXXXX"
        $newline = $newline -replace "CN=[^,]+","CN=XXXXXX"
#        $newline = $newline -replace "\[\S+\]+","[XXXXXX]"
        $newline = $newline -replace "bindDNpassword = .*","bindDNpassword = XXXXX"

        write-host "`noldline: $($line)"
        write-host "newline: $($newline)"

        $newcontent += $newline

    } else {
        $newcontent += $line
    }
}

$newcontent | Add-Content -Path $newfile
write-host "`nMasked content written $($newfile)."