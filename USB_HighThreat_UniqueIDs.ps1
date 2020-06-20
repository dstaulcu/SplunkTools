<#
https://www.silabs.com/community/interface/knowledge-base.entry.html/2013/11/21/windows_usb_devicep-aGxD

Composite USB Device Path Format For Interfaces

For a composite device with multiple interfaces, the device path for each interface might look something like:
\?usb#vid_vvvv&pid_pppp&mi_ii#aaaaaaaaaaaaaaaa#{gggggggg-gggg-gggg-gggg-gggggggggggg}

Where:
vvvv is the USB vendor ID represented in 4 hexadecimal characters.
pppp is the USB product ID represented in 4 hexadecimal characters.
ii is the USB interface number.
aaaaaaaaaaaaaaaa is a unique, Windows-generated string based on things such as the physical USB port address and/or interface number.
gggggggg-gggg-gggg-gggg-gggggggggggg is the device interface GUID that is used to link applications to device with specific drivers loaded.
>>
#>

# this technique only works for usbstuff
$PnpDevices = Get-PnpDevice | ?{$_.Instanceid -match "^USB"}

$Records = @()

foreach ($PnpDevice in $PnpDevices) {

    $PnpDeviceProperty = $PnpDevice | Get-PnpDeviceProperty | Select *

    # Unique ID (aka "serial" appears to be a token inside of device parent key
    $UniqueID = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Parent"}).Data

    $MatchedPattern = $false

    if ($UniqueID) {

        # isolate chars to right of second \, if present
        if (($UniqueID -split "\\").count -eq 3) { 

            $UniqueID = ($UniqueID -split "\\")[2]
            
            if ($UniqueID -match "&") { 
                # use second token after "&" delimeter, if present
                $MatchedPattern = $true
                $UniqueID = ($UniqueID -split "&")[1] 
            } else {
                if ($UniqueID.Length -ne "0") { $MatchedPattern = $true }
            }
        }
    }
    
    # if the property did not have the expected structure, report N/A
    if ($MatchedPattern -eq $false ) { $UniqueID = "n/a" }

    $FirstInstallDate = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_FirstInstallDate"}).Data
    $LastArrivalDate = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_LastArrivalDate"}).Data
    $Category = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_DeviceContainer_Category"}).Data
    $IsPresent =($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_IsPresent"}).Data
    $Parent = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Parent"}).Data

    if ($PnpDevice.Class -match "^(WPD|BLUETOOTH|DiskDrive|Media|Image|WebCam)$") {
        $RiskLevel = "High"
    } else { 
        $RiskLevel = "Undefined"
    }

    $Record  = @{

        FirstInstallDate = $FirstInstallDate
        LastArrivalDate = $LastArrivalDate
        Category = $Category
        IsPresent = $IsPresent
        Parent = $Parent

        UniqueID = $UniqueID        
        Class = $PnpDevice.Class
        Service = $PnpDevice.Service
        Status = $PnpDevice.Status
        FriendlyName = $PnpDevice.FriendlyName
        InstanceID = $PnpDevice.InstanceId

        RiskLevel = $RiskLevel
        

    }


    $Records += New-Object -TypeName PSObject -Property $Record
}

<#
# Reduce list down to devices which are present
$Records = $Records | ?{$_.IsPresent -eq "True"}

# Reduce list down to devices which are high risk
$Records = $Records | ?{$_.RiskLevel -eq "High"}
#>

$Records | Select InstanceID, Class, Service, Category, RiskLevel, FriendlyName, UniqueID, Status, IsPresent, LastArrivalDate, FirstInstallDate | Sort-Object -Property LastArrivalDate -Descending | Out-GridView
