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

<#
# further reduce list down to device classes which are scary exfil channels
- WPD=Phones, DiskDrive=ThumbDrives, Media=Micrphones(sometimes), Image=WebCams(sometimes), WebCam=WebCams(sometimes), BlueTooth=duh)
#>

$PnpDevices = $PnpDevices | ?{$_.class -match "^(WPD|BLUETOOTH|DiskDrive|Media|Image|WebCam)"}

$Records = @()

foreach ($PnpDevice in $PnpDevices) {

    $PnpDeviceProperty = $PnpDevice | Get-PnpDeviceProperty | Select *

    # Unique ID (aka "serial" appears to be a token inside of device parent key
    $UniqueID = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Parent"}).Data
    # isolate chars to right of last backslash
    $UniqueID = ($UniqueID -split "\\")[2]
    # isolate chars between first and second amperstand instance, if exist
    if ($UniqueID -match "&") { $UniqueID = ($UniqueID -split "&")[1] }

    $Record  = @{
        Device_Class = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Class"}).Data
        Device_Manufacturer = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Manufacturer"}).Data
        Device_FriendlyName = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_FriendlyName"}).Data
        Device_FirstInstallDate = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_FirstInstallDate"}).Data
        Device_LastArrivalDate = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_LastArrivalDate"}).Data
        DeviceContainer_Category = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_DeviceContainer_Category"}).Data
        DEVPKEY_Device_IsPresent =($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_IsPresent"}).Data
        DEVPKEY_Device_Parent = ($PnpDeviceProperty | ? {$_.KeyName -eq "DEVPKEY_Device_Parent"}).Data

        UniqueID = $UniqueID        
        PnpDeviceClass = $PnpDevice.Class
        PnpDeviceService = $PnpDevice.Service
        PnpDeviceStatus = $PnpDevice.Status
    }

    $Records += New-Object -TypeName PSObject -Property $Record
}

$Records | Out-GridView
