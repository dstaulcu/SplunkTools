'''''''''''''''''''''''''''''''''''''''''''
' splunkNameCheck.vbs
'
' Checks for splunk universal forwarder whose host computer name has been
' renamed since the splunk unversal forwarder was installed.  Corrects 
' situation when needed. Designed to run as a script-based input which runs 
' at start. 
' 
' https://answers.splunk.com/answers/452782/how-is-server-identified-after-clone-prep-clear-co.html
'''''''''''''''''''''''''''''''''''''''''''
Option Explicit

Dim WshShell, objFSO, objFile
Dim bNeedsPersonalization, strInstallPath, strLocalInputsPath, strLocalServerPath, strInstanceCfgPath
Dim strCommand 

Set WshShell = CreateObject("WScript.Shell")

Const strComponent = "splunkNameCheck"

' assume coming into this script that everything is fine
bNeedsPersonalization = False
		 
' make sure the splunk installation directory exists where we expect it to
Set objFSO = CreateObject("Scripting.FileSystemObject")
strInstallPath = "c:\program files\SplunkUniversalForwarder"
If NOT objFSO.FolderExists(strInstallPath) Then
	' execute the function which checks the file for personalization issues
	wscript.echo strComponent & " - " & chr(34) & strInstallPath & chr(34) & " not found!"
	wscript.quit
End If
	
' make sure the local inputs.conf file exists
strLocalInputsPath = strInstallPath & "\etc\system\local\inputs.conf"
If objFSO.FileExists(strLocalInputsPath) Then
	' execute the function which checks the file for personalization issues
    bNeedsPersonalization = NeedsPersonalization(strLocalInputsPath,"host")
Else
	' if we get here there are different problems to solve. Log and quit
	wscript.echo strComponent & " - " & chr(34) & strLocalInputsPath & chr(34) & " not found!"
	wscript.quit
End If

' make sure the local server.conf file exists
strLocalServerPath = strInstallPath & "\etc\system\local\server.conf"
If objFSO.FileExists(strLocalServerPath) Then
    bNeedsPersonalization = NeedsPersonalization(strLocalServerPath,"serverName")
Else
	' if we get here there are different problems to solve. Log and quit
	wscript.echo strComponent & " - " & chr(34) & strLocalServerPath & chr(34) & " not found!"
	wscript.quit
End If

' make sure the instance.cfg file exists
strInstanceCfgPath = strInstallPath & "\etc\instance.cfg"
If NOT objFSO.FileExists(strInstanceCfgPath) Then
	' if we get here there are different problems to solve. Log and quit
	wscript.echo strComponent & " - " & chr(34) & strInstanceCfgPath & chr(34) & " not found!"
	wscript.quit
End If


' if we get to this point and there is any need for personalization, take action.
if bNeedsPersonalization=True then

	' Erase key "host" in .\etc\system\local\inputs.conf	
	call RemoveLine(strLocalInputsPath,"host")

	' Erase key "serverName" in .\etc\system\local\server.conf
	call RemoveLine(strLocalServerPath,"serverName")

	' Erase key "guid" from instance.cfg
	call RemoveLine(strInstanceCfgPath,"guid")
	
	' Create a 0-bytes file named cloneprep in the $SPLUNK_HOME directory.
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objFile = objFSO.CreateTextFile(strInstallPath & "\cloneprep")
	objFile.close
	
	' finally, we restart splunk using an independent process
	strCommand = "powershell.exe -Command " & chr(34) & "& {" & "Restart-Service -Name SplunkForwarder -Force" & "}" & chr(34)
	wscript.echo strComponent & " - " & "Personalization required. Executing: " & strCommand
	WshShell.Run strCommand,0,False	
else
	wscript.echo strComponent & " - " & "Personalization not required!"
end if


Function NeedsPersonalization(strFilePath,strSpecName)
	Const ForReading = 1 
	
	Dim objFSO, WshNetwork
	Dim strComputerName, objTextFile, strNextLine, strSpecValue
	
	NeedsPersonalization = False

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set WshNetwork = WScript.CreateObject("WScript.Network")
	strComputerName = ucase(WshNetwork.ComputerName)	

	Set objTextFile = objFSO.OpenTextFile(strFilePath, ForReading)

	Do Until objTextFile.AtEndOfStream
		strNextLine = objTextFile.Readline
		' select out the lines which contain references to the supplied spec name
		if instr(1,ucase(strNextLine),ucase(strSpecName))=1 then
			' isolate values associated with the spec name
			strSpecValue = trim(mid(strNextLine,instr(1,strNextLine,"=")+1))
			' check whether the spec value matches actual computer name
			if ucase(strSpecValue)<>ucase(strComputerName) then
				' write some output for splunk to consume in internal logs
				wscript.echo strComponent & " - " & "Value " & chr(34) & strSpecValue & chr(34) & " does not match actual host name " & chr(34) & strComputerName & chr(34) & " in spec with name " & chr(34) & strSpecName & chr(34) & "."
				' return fact that action needs to be taken to main
				NeedsPersonalization = True
			end if
		end if
	Loop
End Function


Function RemoveLine(strFilePath,strSpecName)
	Const ForReading = 1 

	Dim WshShell, objFSO
	Dim tempFileName, strNextLine
	Dim objTemp, objTextFile

	Set WshShell = CreateObject("WScript.Shell")
	tempFileName = WshShell.ExpandEnvironmentStrings("%TEMP%") & "\tmpSplunk.tmp"

	Set objFSO = CreateObject("Scripting.FileSystemObject")

	'create temp file and open for writing
	Set objTemp = objFSO.OpenTextFile(tempFileName, 2, True)
	
	'open original file for reading
	Set objTextFile = objFSO.OpenTextFile(strFilePath, ForReading)
	
	'write each line of orig file to temp file excep line associated with specName
	Do Until objTextFile.AtEndOfStream
		strNextLine = objTextFile.Readline
		' select out the lines which contain references to the supplied spec name
		if instr(1,ucase(strNextLine),ucase(strSpecName))=1 then
			' do nothing, exclude this file from temp
		else
			objTemp.WriteLine strNextLine		
		end if
	Loop

	'close handles to files
	objTextFile.Close
	objTemp.Close

	'replace orig file with temp file
	objFSO.CopyFile tempFileName, strFilePath, True
	
	'remove temp file
	objFso.DeleteFile(tempFileName)
End Function


'''''''''''''''''''''''''''''''''''''''''''
' INPUTS.CONF
'
' [script://.\bin\splunkNameCheck.path]
' disabled = 0
' interval = -1
' source = splunkNameCheck
' sourcetype = script:cscript
' index = _internal
'''''''''''''''''''''''''''''''''''''''''''

'''''''''''''''''''''''''''''''''''''''''''
' splunkNameCheck.path
'
' C:\Windows\system32\cscript.exe -NoLogo "C:\Program Files\SplunkUniversalForwarder\etc\apps\UF-CORE\bin\splunkNameCheck.vbs"
'''''''''''''''''''''''''''''''''''''''''''

'''''''''''''''''''''''''''''''''''''''''''
' SPL
'
' index=_internal source=splunkNameCheck
' |  table _time host index sourcetype source _raw
' |  sort - _time
'''''''''''''''''''''''''''''''''''''''''''

