@echo off
set SplunkApp=UF-CORE-WIN-PRD
powershell.exe -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\checkSplunkCerts.ps1'"
