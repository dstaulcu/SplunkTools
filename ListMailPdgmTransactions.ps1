
$Account = "email"
$Sender = "sender"

$ol = New-Object -comObject Outlook.Application 
$ns = $ol.GetNameSpace("MAPI")

$MailItems = $ns.Session.Folders.Item($Account)

# list all folders where default item type is message class
$MailFolders = $MailItems.Folders | ?{(($_.DefaultItemType -eq 0) -and ($_.Name -match "(pgdm)"))} 

$transactions = @()

foreach ($MailFolder in $MailFolders) {
      
    # get items to evaluate
    $FolderItems = $MailItems.Folders.Item($MailFolder.Name).Items

    foreach ($FolderItem in $FolderItems) {

        # Add properties of interest for items of mail class to transactions object
        if ($FolderItem.class -eq 43) {

            if ($FolderItem.SenderEmailAddress -eq $Sender) {

                if ($FolderItem.Subject -match "!") {

                    $subject  = $FolderItem.Subject -replace "!",""

                    $transaction = new-object -TypeName PSObject
                    $transaction | Add-Member -MemberType NoteProperty -Name FolderName -Value $MailFolder.Name
                    $transaction | Add-Member -MemberType NoteProperty -Name Class -Value $FolderItem.Class
                    $transaction | Add-Member -MemberType NoteProperty -Name SenderEmailAddress -Value $FolderItem.SenderEmailAddress
                    $transaction | Add-Member -MemberType NoteProperty -Name CreationTime -Value $FolderItem.CreationTime
                    $transaction | Add-Member -MemberType NoteProperty -Name CreationTimeShort -Value $FolderItem.CreationTime.ToString("yyyy-MM-dd")
                    $transaction | Add-Member -MemberType NoteProperty -Name DayOfWeek -Value $FolderItem.CreationTime.DayOfWeek
                    $transaction | Add-Member -MemberType NoteProperty -Name Subject -Value $Subject
                    $Salutation = ($FolderItem.Subject -split ",")[0]
                    $transaction | Add-Member -MemberType NoteProperty -Name Server -Value $Salutation
                    $transactions += $transaction
                }
            }
        }
    }
}


$transactions = $transactions | Sort-Object -Property CreationTime -Descending
$transactions | Out-GridView
$outputfile = "$($env:userprofile)\Desktop\mailsummary.csv"
if (Test-Path $outputfile) { Remove-Item $outputfile -Force }
$transactions | Export-Csv -Path $outputfile -NoTypeInformation
