@echo off

if %PROCESSOR_ARCHITECTURE%==x86 goto 32BIT

:64BIT
echo 64-bit Windows installed
msiexec.exe /i %~dp0\splunkforwarder-7.0.0-c8a78efdd40f-x64-release.msi AGREETOLICENSE=Yes RECEIVING_INDEXER="" DEPLOYMENT_SERVER="splunk-dev.cloudapp.net:8089" /quiet
goto END


:32BIT
echo 32-bit Windows installed
msiexec.exe /i %~dp0\splunkforwarder-7.0.0-c8a78efdd40f-x86-release.msi AGREETOLICENSE=Yes RECEIVING_INDEXER="" DEPLOYMENT_SERVER="splunk-dev.cloudapp.net:8089" /quiet
goto END

:END
echo Finished.