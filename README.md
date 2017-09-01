# SplunkTools
A collection of scripts useful in management of Splunk deployment

Remove-UniversalForwarder-BrokenMSI.ps1
 - script of last resort to remove splunk universal forwarder when MSI package fails to do so.
 
DoImmediatePhoneHome.ps1
 - script to temporarily comment phoneHomeInterval in active deploymentclient.conf and restart splunk in order to force phone home to deployment server in the next 60 seconds.
