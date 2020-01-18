Option Explicit

Const ForReading = 1
Const ForWriting = 2
Const ForAppending = 8


Dim objFSO, objFile
Set objFSO = CreateObject("Scripting.FileSystemObject")

Dim strLogConfigFile 
strLogConfigFile = "C:\Program Files\SplunkUniversalForwarder\etc\log.cfg"

' make sure the log configuration file exists before proceeding
if CheckFileExists(strLogConfigFile)=False then
	wscript.echo "File (" & strLogConfigFile & ") does not exist. Exiting."
	wscript.quit
End if

' if we have do not have a backup of the file, create one
dim strLogConfigFileBak
strLogConfigFileBak = strLogConfigFile & ".bak"
if CheckFileExists(strLogConfigFileBak)=False then
	objFso.CopyFile strLogConfigFile,strLogConfigFileBak
End if

' load dictionary of specs to change
Dim objDictionary
Set objDictionary = CreateObject("Scripting.Dictionary")
objDictionary.CompareMode = vbTextCompare
objDictionary.Add "category.DC:UpdateServerclassHandler","WARN"
objDictionary.Add "category.DeployedServerclass","WARN"
objDictionary.Add "category.MetricStoreCatalogBaseHandler=INFO","WARN"
objDictionary.Add "category.MetricsHandler=INFO","WARN"
objDictionary.Add "category.MetricSchemaProcessor=INFO","WARN"
objDictionary.Add "category.MetricsRollupPolicyHandler=INFO","WARN"
objDictionary.Add "category.TailingProcessor=INFO","WARN"
objDictionary.Add "category.WatchedFile=INFO","WARN"
objDictionary.Add "category.ChunkedLBProcessor=INFO","WARN"
objDictionary.Add "category.MetricsProcessor=INFO","WARN"
objDictionary.Add "category.TailReader=INFO","WARN"
objDictionary.Add "category.CertStorageProvider=INFO","WARN"
objDictionary.Add "category.Rsa2FA=INFO","WARN"
objDictionary.Add "category.IndexerInit=INFO","WARN"
objDictionary.Add "category.DC:DeploymentClient=INFO","WARN"
objDictionary.Add "category.DC:PhonehomeThread=INFO","WARN"
objDictionary.Add "category.DS_DC_Common=INFO","WARN"
objDictionary.Add "category.IntrospectionGenerator:disk_objects=INFO","WARN"
objDictionary.Add "category.ModularInputs=INFO","WARN"
objDictionary.Add "category.PipelineComponent=INFO","WARN"
objDictionary.Add "category.PrometheusMetricsHandler=INFO","WARN"
objDictionary.Add "category.ProxyConfig=INFO","WARN"
objDictionary.Add "category.ShutdownHandler=INFO","WARN"
objDictionary.Add "category.SpecFiles=INFO","WARN"
objDictionary.Add "category.TcpOutputProc=INFO","WARN"
objDictionary.Add "category.TcpInputProc=INFO","WARN"
objDictionary.Add "category.ScheduledViewsReaper=INFO","WARN"
objDictionary.Add "category.BundlesSetup=INFO","WARN"
objDictionary.Add "category.CascadingReplicationManager=INFO","WARN"
objDictionary.Add "category.WorkloadManager=INFO","WARN"
objDictionary.Add "category.ExecProcessor=INFO","WARN"
objDictionary.Add "category.ExecProcessor:Introspect=INFO","WARN"
objDictionary.Add "category.LicenseMgr=INFO","WARN"
objDictionary.Add "category.LMConfig=INFO","WARN"
objDictionary.Add "category.LMSlaveInfo=INFO","WARN"
objDictionary.Add "category.LMStack=INFO","WARN"
objDictionary.Add "category.LMStackMgr=INFO","WARN"
objDictionary.Add "category.LMTracker=INFO","WARN"
objDictionary.Add "category.LMTrackerDb=INFO","WARN"
objDictionary.Add "category.ApplicationLicense=INFO","WARN"
objDictionary.Add "category.ApplicationLicenseHandler=INFO","WARN"
objDictionary.Add "category.ApplicationLicenseTracker=INFO","WARN"
objDictionary.Add "category.ClusteringMgr=INFO","WARN"
objDictionary.Add "category.PipeFlusher=INFO","WARN"
objDictionary.Add "category.SHClusterMgr=INFO","WARN"
objDictionary.Add "category.UiHttpListener=INFO","WARN"
objDictionary.Add "category.FileAndDirectoryEliminator=INFO","WARN"
objDictionary.Add "category.Metrics=INFO,metrics","WARN"
objDictionary.Add "category.StatusMgr=INFO,metrics","WARN"
objDictionary.Add "category.PeriodicHealthReporter=INFO,healthreporter","WARN"
objDictionary.Add "category.Watchdog=INFO,watchdog_appender","WARN"
objDictionary.Add "category.WatchdogActions=INFO,watchdog_appender","WARN"
objDictionary.Add "category.Pstacks=INFO,watchdog_appender","WARN"
objDictionary.Add "category.PstackServerThread=INFO,watchdog_appender","WARN"
objDictionary.Add "category.PstackGeneratorThread=INFO,watchdog_appender","WARN"
objDictionary.Add "category.WatchdogStacksUtils=INFO,watchdog_appender","WARN"
objDictionary.Add "category.WatchdogInit=INFO,watchdog_appender","WARN"

' read the file into array
Set objFile = objFSO.OpenTextFile(strLogConfigFile, ForReading)
Dim arrFileLines()
Dim i
i = 0
Do Until objFile.AtEndOfStream
     Redim Preserve arrFileLines(i)
     arrFileLines(i) = objFile.ReadLine
     i = i + 1
Loop
objFile.Close

' step through array (lines of file)
Dim strLine
Dim objItem
Dim blnReplacementNeeded :: blnReplacementNeeded = False

Dim arrNewFile()
Dim j :: j = 0


Dim blnSplunkdSection :: blnSplunkdSection = False
For i = 0 to Ubound(arrFileLines)
	strLine = arrFileLines(i)

	' determine if we are in the splunkd section or not
	if instr(1,ucase(strLine),"[")=1 then
		if instr(1,ucase(strLine),"[SPLUNKD]")<>0 then
			blnSplunkdSection = True
		else 
			blnSplunkdSection = False
		end if
	end if

	' only evaluate lines in splunkd section, which are not commented, and which have "=INFO" substring
	if blnsplunkdSection = True AND left(strLine,1)<>"#" AND instr(1,strLine,"=INFO")<>0 then

		' Check to to see of log component (left side of = in line) matches an item (key) in list (dictionary)
		For Each objItem in objDictionary.keys
			if instr(1,ucase(strLine),ucase(objItem))=1 then
				blnReplacementNeeded = true
				strLine = replace(strLine,"=INFO","=" & objDictionary(objItem))
				exit for
			end if				
		Next
	end if
		
	Redim Preserve arrNewFile(j)
	arrNewFile(j) = strLine
	j = j + 1									
	
Next

' if there was a need to replace text, write new file array to file
if blnReplacementNeeded = true then

	' delete the file if exist
	if CheckFileExists(strLogConfigFile) then
		objFSO.deletefile strLogConfigFile,true
	end if

	' write lines to replacement file
	dim objTextFile
	Set objTextFile = objFSO.OpenTextFile(strLogConfigFile,ForAppending, True)

	For j=0 to ubound(arrNewFile)
		objTextFile.writeline arrNewFile(j)
	Next

	' release handle to file`
	objTextFile.Close

end if
	

Function CheckFileExists(strFile)
	Dim objFSO
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	CheckFileExists = objFSO.FileExists(strFile)
End Function

