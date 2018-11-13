Option Explicit

Dim blnDebug :: blnDebug = False

Function FolderExists(strFolderName)
	Dim objFSO :: Set objFSO = CreateObject("Scripting.FileSystemObject")
	
	If objFSO.FolderExists(strFolderName) Then
		FolderExists = True
	else
		FolderExists = False		
	End If
	
	Set objFSO = Nothing
End Function

Function GetSystemArchitecture
	Dim WshShell
	Dim WshProcEnv
	Dim system_architecture
	Dim process_architecture

	Set WshShell =  CreateObject("WScript.Shell")
	Set WshProcEnv = WshShell.Environment("Process")

	process_architecture= WshProcEnv("PROCESSOR_ARCHITECTURE") 

	If process_architecture = "x86" Then    
		system_architecture= WshProcEnv("PROCESSOR_ARCHITEW6432")

		If system_architecture = ""  Then    
			system_architecture = "x86"
		End if    
	Else    
		system_architecture = process_architecture    
	End If
		
	GetSystemArchitecture = system_architecture
	
	Set WshShell = Nothing
	Set WshProcEnv = Nothing
End Function	

Function GetLastFolderAge(strFolder)
	Dim objFSO :: Set objFSO = CreateObject("Scripting.FileSystemObject")
	Dim objFolder, colSubfolders, objSubfolder, strCurrentFolderName
	
	Dim LastFolder, LastDate, LastFolderAge
	
	Set objFolder = objFSO.GetFolder(strFolder)
	Set colSubfolders = objFolder.Subfolders

	For Each objSubfolder in colSubfolders
		strCurrentFolderName = ucase(objSubfolder.Name)
		if (strCurrentFolderName = ucase("introspection_generator_addon") Or _
			strCurrentFolderName = ucase("learned") Or _
			strCurrentFolderName = ucase("search") Or _
			strCurrentFolderName = ucase("SplunkUniversalForwarder") Or _
			strCurrentFolderName = ucase("splunk_httpinput")) Then
			' do nothing
		else
			' get the age of the folder
			If objSubfolder.DateLastModified > LastDate Or IsEmpty(LastDate) Then
				LastFolder = objSubfolder.Name
				LastDate = objSubfolder.DateLastModified
			End If			
		end if
	Next
	
	if LastFolder = "" Or isnull(LastFolder) Then	
		LastFolderAge = -1
	Else
		LastFolderAge = datediff("d",LastDate,now())
	End if
	
	if blnDebug = True then
		wscript.echo "LastFolder: " & LastFolder
		wscript.echo "LastDate: " & LastDate
		wscript.echo "LastFolderAge: " & LastFolderAge
	end if
	
	GetLastFolderAge = LastFolderAge

	Set objFSO = Nothing
	Set objFolder = Nothing
	Set colSubfolders = Nothing
End Function

Function GetServiceStatus(strServiceName)
	dim objWMIService, colListOfServices, objService

	Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
	Set colListOfServices = objWMIService.ExecQuery _
		("Select * from Win32_Service Where Name = '" & strServiceName & "'")

	GetServiceStatus = False		
	if isobject(colListOfServices) then
		if colListOfServices.Count > 0 then
			GetServiceStatus = True
		end if
	end if
	
	Set objWMIService = Nothing
	Set objService = Nothing		
End Function

Private Function CheckFileFullControl(FolderName,TrusteeDomain,TrusteeName)
	CheckFileFullControl = False
	
	Const FullAccessMask = 2032127, ModifyAccessMask = 1245631, WriteAccessMask = 1180095 
	Const ROAccessMask = 1179817 

	Dim strComputer :: strComputer = "." 
	 
	'Build the path to the folder because it requites 2 backslashes 
	Dim folderpath :: folderpath = Replace(FolderName, "\", "\\") 
	 
	Dim objectpath, wmiFileSecSetting, wmiSecurityDescriptor, RetVal, DACL, wmiAce, Trustee, FoundAccessMask, CustomAccessMask, AccessType 
	objectpath = "winmgmts:Win32_LogicalFileSecuritySetting.path='" & folderpath & "'" 
	 
	'Get the security set for the object 
	Set wmiFileSecSetting = GetObject(objectpath) 
	 
	'verify that the get was successful 
	RetVal = wmiFileSecSetting.GetSecurityDescriptor(wmiSecurityDescriptor) 
	'If Err <> 0 Then 
		'MsgBox ("GetSecurityDescriptor failed" & vbCrLf & Err.Number & vbCrLf & Err.Description) 
		'End 
	'End If 
	  
	' Retrieve the DACL array of Win32_ACE objects. 
	DACL = wmiSecurityDescriptor.DACL  
	For Each wmiAce In DACL 
		' Get Win32_Trustee object from ACE 
		Set Trustee = wmiAce.Trustee 		
								
		FoundAccessMask = False 
		CustomAccessMask = False
		While Not FoundAccessMask And Not CustomAccessMask 
			If wmiAce.AccessMask = FullAccessMask Then 
				AccessType = "Full Control" 
				FoundAccessMask = True 
			End If 
			If wmiAce.AccessMask = ModifyAccessMask Then 
				AccessType = "Modify" 
				FoundAccessMask = True 
			End If 
			If wmiAce.AccessMask = WriteAccessMask Then 
				AccessType = "Read/Write Control" 
				FoundAccessMask = True 
			End If 
			If wmiAce.AccessMask = ROAccessMask Then 
				AccessType = "Read Only" 
				FoundAccessMask = True 
			Else 
				CustomAccessMask = True 
			End If 
		Wend 
		   
		If FoundAccessMask Then 
			'wscript.echo AccessType 
		Else 
			AccessType = "Custom" 
		End If 
		
		'wscript.echo FolderName & "," & Trustee.Domain & "\" & Trustee.Name & "," & AccessType
		
		if (ucase(TrusteeDomain) = ucase(Trustee.Domain)) and _
			(ucase(TrusteeName) = ucase(Trustee.Name)) and _
			AccessType = "Full Control" then						
			CheckFileFullControl = True
		end if		
	Next
End Function

Function RegExMatch(strString,strPattern)
    Dim RegEx
    RegExMatch=False
    
    Set RegEx = New RegExp                
    RegEx.IgnoreCase = True                
    RegEx.Global=True                   
    RegEx.Pattern=strPattern
    
    If RegEx.Test(strString) Then RegExMatch=True
 
End Function 
 
Function GetMatch(strString,strPattern)
    Dim RegEx,arrMatches, colMatches
    Set RegEx = New RegExp                
    RegEx.IgnoreCase = True                
    RegEx.Global=True                   
    RegEx.Pattern=strPattern
    Set colMatches=RegEx.Execute(strString)
    Set GetMatch=colMatches
End Function

Function ReadLog(strFileName)
	Const ForReading = 1

	Dim ObjFSO, objTextFile, strText, arrLines, i, strLine, matches, match, RecordAge
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objTextFile = objFSO.OpenTextFile(strFileName, ForReading)
	strText = objTextFile.ReadAll
	objTextFile.Close

	arrLines = Split(strText, vbCrLf)
	
	' scan the last 50 lines
	For i = ubound(arrLines)-50 to ubound(arrLines)
		strLine = arrLines(i)
		
		' get the date from the line
		Set matches=GetMatch(strLine,"^\d+-\d+-\d+")
		For Each match In matches
			RecordAge = datediff("d",match.value,now())
			' show records where date is recent
			if RecordAge <= 1 then
				' show records which would prevent phone home or tcp connection
				if RegExMatch(strLine,"\s+(WARN|ERROR)\s+(TcpOutput|DC:DeploymentClient|HttpPubSubConnection)") then		
					wscript.echo strLine
				end if
			end if
		Next
	Next
End Function

Dim strSplunkHome :: strSplunkHome = "C:\Program Files\SplunkUniversalForwarder"
Dim strSplunkApps :: strSplunkApps = strSplunkHome & "\etc\apps"
Dim strSplunkdLog :: strSplunkdLog = strSplunkHome & "\var\log\splunk\splunkd.log"

Wscript.echo "Splunk home folder exists: " & FolderExists(strSplunkHome)
Wscript.echo "Splunk apps folder exists: " & FolderExists(strSplunkApps)
wscript.echo "Operating system architecture: " & GetSystemArchitecture
wscript.echo "Last Apps Folder Age: " & GetLastFolderAge(strSplunkApps)
wscript.echo "ServiceStatus: " & GetServiceStatus("SplunkForwarder")
wscript.echo "CheckFileFullControl (" & strSplunkHome & "): " & CheckFileFullControl(strSplunkHome,"NT AUTHORITY","SYSTEM")
wscript.echo "CheckFileFullControl (" & strSplunkApps & "): " & CheckFileFullControl(strSplunkApps,"NT AUTHORITY","SYSTEM")

ReadLog strSplunkdLog

