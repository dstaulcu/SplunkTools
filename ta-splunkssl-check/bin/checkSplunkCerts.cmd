@echo off
set SplunkApp=ta-splunkssl-check
powershell.exe -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\checkSplunkCerts.ps1'"
