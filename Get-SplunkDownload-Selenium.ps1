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

## gather cred from store
$url = [uri]"https://login.splunk.com/?module=roles&func=showloginform"
$mycredfile = "$($workingPath)\mycred.xml"
if (!(Test-Path -Path $mycredfile)) {
    Get-Credential -Message "Enter credential for $($url.host)" | Export-Clixml -path $mycredfile
}
$cred = Import-Clixml $mycredfile
$user = $cred.UserName
$pass = [System.Net.NetworkCredential]::new("", $cred.Password).Password


# Add the working directory to the environment path.  This is required for the ChromeDriver to work.
if (($env:Path -split ';') -notcontains $workingPath) {
    $env:Path += ";$workingPath"
}

# Import Selenium to PowerShell using the Add-Type cmdlet.
Add-Type -Path "$($workingPath)\WebDriver.dll"

# Create a new ChromeDriver Object instance.
$ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver

# Launch a browser and go to Logon URL
$ChromeDriver.Navigate().GoToURL("$($url.AbsoluteUri)")

# Enter the username in the Username box
$ChromeDriver.FindElementByXPath('//*[@id="login-form"]/div/div[1]/div[2]/div/input').SendKeys($user)

# Click on the Next button
$ChromeDriver.FindElementByXPath('//*[@id="login-form"]/div/div[3]/button/span/span').Click()

# Enter the password in the Password box
$ChromeDriver.FindElementByXPath('//*[@id="login-form"]/div/div[2]/div[2]/div/input').SendKeys($pass)

# Click on the Login button
$ChromeDriver.FindElementByXPath('//*[@id="login-form"]/div/div[4]/button/span').Click()

# wait for logon process to complete by waiting for "loggedinusername" with text David for certain period of time
$LogonReady = $false
$LogonWait = 20 #seconds
$LogonWaitCounter = 0
while($LogonReady -eq $false) {

    if ($LogonWaitCounter -eq $LogonWait) { 
        write-host "Timed out waiting $($logonWaitCounter) seconds for logon to complete. Exiting."
        $ChromeDriver.Close()
        $ChromeDriver.Quit()
        exit
    }

    Write-Progress -Activity "Waing for Splunk logon to complete..." -SecondsRemaining ($LogonWait - $LogonWaitCounter)

    $loggedinusername = $ChromeDriver.FindElementByXPath('//*[@id="loggedinusername"]')
    if ($loggedinusername.Text -eq "David" -and $loggedinusername.Enabled -eq "True") {
        $LogonReady = $True
        Write-Progress -Activity "Waing for Splunk logon to complete..." -Completed
    } else {
        Start-Sleep -Seconds 1
        $LogonWaitCounter++
    }
}

# now that logon is done, goto universal forwarder download url
$ChromeDriver.Navigate().GoToURL('https://www.splunk.com/en_us/download/previous-releases/universalforwarder.html')

# click download button in position (2nd in table) of most recent x64 based universal forwarder
$ChromeDriver.FindElementByXPath('//*[@id="windows-collapse"]/div/div/div[2]/div[4]/table/tbody/tr/td[3]/a').Click()

# todo:  figure out a way to "confirm" download OR just scrape url element points to and invoke-webrequest outside of selenium.

Read-Host "Press Enter to close and quit selenium session."

# Cleanup
$ChromeDriver.Close()
$ChromeDriver.Quit()




