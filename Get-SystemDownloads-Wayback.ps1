<#
https://adamtheautomator.com/getting-started-in-web-automation-with-powershell-and-selenium/

Required Resources:
https://www.selenium.dev/downloads/   #Selenium Client & WebDriver Language Bindings for C#
https://sites.google.com/a/chromium.org/chromedriver/downloads


API Documentation for WebDriver for C#
https://www.selenium.dev/selenium/docs/api/dotnet/index.html

#>

# Your working directory
$workingPath = 'C:\apps\selenium'

# Add the working directory to the environment path.  This is required for the ChromeDriver to work.
if (($env:Path -split ';') -notcontains $workingPath) {
    $env:Path += ";$workingPath"
}

# Import Selenium to PowerShell using the Add-Type cmdlet.
Add-Type -Path "$($workingPath)\WebDriver.dll"

# Create a new ChromeDriver Object instance.
$ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver

# Launch a browser and go to Logon URL
$ChromeDriver.Navigate().GoToURL("http://web.archive.org/web/*/https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon")
do
{
    write-host "Sleeping until calendar-day elemnts are present..."
    Start-Sleep -Seconds 1    
}
until ($ChromeDriver.FindElementsByClassName('calendar-day'))

$Entries = $ChromeDriver.FindElementsByTagName('a') | ?{$_.Text -match "^\d+$"}
$UrlList = @()
foreach ($Entry in $Entries) {
    $UrlList += $Entry.GetAttribute('href')
}
$ChromeDriver.Close()
$ChromeDriver.Quit()


foreach ($url in $UrlList) {
    write-host $url

    $download = ((Invoke-WebRequest -uri $url -UseBasicParsing).links | ?{$_.href -match "sysmon.zip"})[-1].href
    $file = [regex]::Match($download,"web/(\d+)/https").groups[1].value
    Start-BitsTransfer -Source $download -Destination "$($env:temp)\sysmon_$($file).zip" -Dynamic



}

