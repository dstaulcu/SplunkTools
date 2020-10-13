<#
Check for permissions issues and correct them
#>

<# Debug mode switches
$DebugPreference = "Continue"           # Debug Mode
$DebugPreference = "SilentlyContinue"   # Normal Mode
#>

#Checks if the user is in the administrator group. Warns and stops if the user is not.
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-host "You are not running this as local administrator. Run it again in an elevated prompt."
    exit
}

# define top level folder of interest
$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"

# Define list of critical objects requiring special permissions
$CriticalObjects = @("$($SplunkHome)\etc\apps"
    ,"$($SplunkHome)\etc\auth"
    ,"$($SplunkHome)\etc\apps"
    ,"$($SplunkHome)\etc\system"
    ,"$($SplunkHome)\var\log"
    ,"$($SplunkHome)\var\run")


function Get-ChildItemUnauthorizedAccessError {
    param (
    [parameter(Mandatory=$true)][string]$Folder
    ,[parameter(Mandatory=$true)][bool]$Recurse=$false
    ,[Parameter(Mandatory=$true)][ValidateSet("Directory", "File", "All")]$ObjectType="Directory"
    )

    $Error.Clear()

    if ($ObjectType -eq "All") {
        $Objects = Get-ChildItem -Path $Folder -Recurse:$Recurse -ErrorAction SilentlyContinue
    }

    if ($ObjectType -eq "File") {
        $Objects = Get-ChildItem -Path $Folder -Recurse:$Recurse -File -ErrorAction SilentlyContinue
    }

    if ($ObjectType -eq "Directory") {
        $Objects = Get-ChildItem -Path $Folder -Recurse:$Recurse -Directory -ErrorAction SilentlyContinue
    }

    $Issues = $Error | ?{$_.FullyQualifiedErrorId -match "UnauthorizedAccessError"}

    return $Issues
}


# do initial permission check
$Issues = Get-ChildItemUnauthorizedAccessError -Folder $SplunkHome -Recurse $true -ObjectType All

if ($Issues) {

    # List files or folders to which access was denied
    foreach ($Issue in $Issues) {
        write-host $Issue.ToString()
        
    }

    # Reset permissions (and ownership) on all items to match that of reference folder
    $ReferenceACL = Get-Acl -Path $env:ProgramFiles 
    Get-ChildItem -Path $SplunkHome -Recurse | %{ $ReferenceACL | Set-Acl -Path $_.FullName }

    # Remove user level access from critical objects
    foreach ($object in $CriticalObjects) {

        # Check to see if path exists
        if (Test-Path -Path $object) {

            # Remove inheritance
            $acl = Get-Acl -Path $object
            $acl.SetAccessRuleProtection($true,$true)
            Set-Acl -Path $object -AclObject $acl

            # Remove BUILTIN\User ACEs
            $acl = Get-Acl -Path $object
            $acesToRemove = $acl.Access | ?{ $_.IsInherited -eq $false -and $_.IdentityReference -eq 'BUILTIN\Users' }
            if ($acesToRemove) {
                foreach ($aceToRemove in $acesToRemove) {
                    $acl.RemoveAccessRule($aceToRemove) | Out-Null
                }
                Set-Acl -AclObject $acl -Path $object
            }

            # Recurse the change from this object to it's children
            $ReferenceACL = Get-Acl -Path $object
            Get-ChildItem -Path $object -Recurse | %{ $ReferenceACL | Set-Acl -Path $_.FullName }    
        }
    } 

} else {
    write-host "No persmission issues under $($SplunkHome)"
}

<#
# Remove NT AUTHORITY\SYSTEM ACEs  (to get environment to broken state again)
$SplunkHome = "C:\Program Files\SplunkUniversalForwarder"
$object = "$($SplunkHome)\etc\apps"
$acl = Get-Acl -Path $object
$acesToRemove = $acl.Access | ?{ $_.IsInherited -eq $false -and $_.IdentityReference -match '(NT AUTHORITY\\SYSTEM|BUILTIN\\Administrators)' }
if ($acesToRemove) {
    foreach ($aceToRemove in $acesToRemove) {
        $acl.RemoveAccessRule($aceToRemove) | Out-Null
    }
    Set-Acl -AclObject $acl -Path $object

    # Recurse the change from this object to children
    $ReferenceACL = Get-Acl -Path $object
    Get-ChildItem -Path $object -Recurse | %{ $ReferenceACL | Set-Acl -Path $_.FullName }
}

((Get-Acl -Path $object).access).identityReference
#>
