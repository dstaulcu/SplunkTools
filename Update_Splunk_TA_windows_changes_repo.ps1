<#
.Synopsis
   Update https://github.com/dstaulcu/Splunk_TA_windows to include from most recent release on splunkbase
.Instructions  
   download all versions of Splunk_TA_windows from splunkbase into user profile downloads folder
   pre-extract all tar, gz files using 7zip
   delete and re-create repository
   script steps through each download and rebuilds repository
#>



<# 
PLACEHOLDER TO PLACE TOGGLE DEBUG/NORMAL MODE AS NEEDED
$DebugPreference = "Continue"
$DebugPreference = "SilentlyContinue"
#>

$directory_base = "$($env:USERPROFILE)\Downloads"
$repository_url = "https://github.com/dstaulcu/Splunk_TA_windows.git"
$respository_name = ($repository_url -split "/")[-1] -replace ".git",""
$directory_localrepo = "$($directory_base)\$($respository_name)"
$readme_md_path = "$($directory_base)\$($respository_name)\readme.md"
$gitpath = "C:\Program Files\Git\cmd\git.exe"
$version_last = ""

# make sure we are in the directory base at the start
Set-Location -Path "$($directory_base)"

# remove the local copy of repository if it exists
if (Test-Path -Path $directory_localrepo) { Remove-Item -Path $directory_localrepo -Recurse -Force }


# work with each downloaded (and extracted) app present
$expanded_apps = (Get-ChildItem -Path $directory_base -Filter $respository_name -Recurse -Directory).FullName

foreach ($expanded_app in $expanded_apps) {

    # make sure we are in the directory base at the start of each loop
    Set-Location -Path "$($directory_base)"

    # this is the path to the downloaded and expanded app
    write-debug "app folder: $($expanded_app)"

    # get app version into variable
    $appfile = $expanded_app | Get-ChildItem -Recurse -Filter "app.conf" -File | Where-Object {$_.FullName -match "Splunk_TA_windows\\default"}
    $version = $appfile | Get-Content | Select-String -Pattern "version"
    $version = (($version -split "=")[1]).trim()
    Write-Debug "version: $($version)"

    # change directory to the parent of repo to work in
    Set-Location -Path $directory_base

    # remove the local copy of repository if it exists
    if (Test-Path -Path $directory_localrepo) { Remove-Item -Path $directory_localrepo -Recurse -Force }

    # clone the repo
    Start-Process -FilePath "`"$($gitpath)`"" -ArgumentList 'clone',$($repository_url) -Wait

    # move to the repo location
    Set-Location -Path "$($directory_localrepo)"

    # create a branch to work within
    Start-Process -FilePath "`"$($gitpath)`"" -ArgumentList 'checkout','-b',"`"$($version)`"" -Wait

    # remove everything in branch except the .git folder
    remove-item -Path "$($directory_localrepo)\$($respository_name)" -Recurse -Force

    # copy all the new files in
    Copy-Item -Path $expanded_app -Destination "$($directory_localrepo)" -recurse -Force

    # update the readme.md file
    $readme_md = @()
    $readme_md += "# Splunk_TA_windows"
    $readme_md += "Revision history for Splunk_TA_Windows"
    $readme_md += ""
    $readme_md += "[Compare](https://github.com/dstaulcu/Splunk_TA_windows/compare) changes in files between selected versions of Splunk_TA_Windows since version 5.0.1 This capability is particularly useful as a complement to release notes to better understand new features or to identify potential sources of problems with upgrades."
    $readme_md += ""
    if ($version_last -ne "") {
        $readme_md += "For example, compare [changes](https://github.com/dstaulcu/Splunk_TA_windows/compare/$($version_last)...$($version)?diff=split) between versions $($version_last) and $($version)"
    }
    if (Test-Path -Path $readme_md_path) { Remove-Item -Path $readme_md_path }
    $readme_md | Set-Content -Path $readme_md_path

    # register all the file changes
    Start-Process -FilePath "`"$($gitpath)`"" -ArgumentList 'add','-A' -Wait

    # commit the changes
    Start-Process -FilePath "`"$($gitpath)`"" -ArgumentList 'commit','-m',"`"$($version)`"" -Wait

    # push the changes
    Start-Process -FilePath "`"$($gitpath)`"" -ArgumentList 'push','origin',"`"$($version)`"" -Wait

    # wait
    write-host "press any key to continue once you have merged content on github"
    pause

    $version_last = $version

}
