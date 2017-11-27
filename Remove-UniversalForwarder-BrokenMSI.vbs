option explicit

Dim objShell :: Set objShell = CreateObject("WScript.Shell")
Dim ServiceResults
'### IF SERVICE IS RUNNING, STOP AND DELETE IT
dim objWMIService, colListOfServices, objService
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\.\root\cimv2")
Set colListOfServices = objWMIService.ExecQuery _
    ("Select * from Win32_Service Where Name = 'SplunkForwarder'")
For Each objService in colListOfServices
	wscript.echo "Removing service: " & objService.Name
    ServiceResults = objService.StopService()
    objService.Delete()
	wscript.sleep(5000)
Next
	
'### IF INSTALLATION DIRECTORY IS PRESENT, REMOVE IT
Dim objFso :: Set objfso = CreateObject("Scripting.FileSystemObject")
dim strSplunkHome :: strSplunkHome = "C:\Program Files\SplunkUniversalForwarder"
if objFso.FolderExists(strSplunkHome) then
	wscript.echo "Removing folder: " & strSplunkHome	
	objFSO.DeleteFolder(strSplunkHome)
end if

'### IF DRIVERS ARE PRESENT, REMOVE THEM
Dim objReg, strKeyPath, arrSubKeys, subkey, arrValueNames, arrValueTypes, key, displayName, description
Const HKLM = &H80000002
strKeyPath = "SYSTEM\CurrentControlSet\Services"
Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
objReg.EnumKey HKLM, strKeyPath, arrSubKeys
On Error Resume Next
For Each key in arrSubKeys
	objReg.GetStringValue HKLM,strKeyPath & "\" & key,"DisplayName", displayName
	objReg.GetStringValue HKLM,strKeyPath & "\" & key,"Description", description
	If ((InStr(LCase(key),lcase("Splunk")) > 0) or (InStr(LCase(displayName),lcase("Splunk")) > 0) or (InStr(LCase(description),lcase("Splunk")) > 0)) Then
		if Is64 = True then
			DeleteRegistryKey "64","HKLM" & "\" & strKeyPath & "\" & key
		else 
			DeleteRegistryKey "32","HKLM" & "\" & strKeyPath & "\" & key
		end if
	End If
Next
On Error Goto 0

'### IF UNINSTALL KEY IS PRESENT, REMOVE IT
dim sResults, sOsArch, bMatch, sInstalledArch, keyPath, key64Path
sOsArch = GetOSSystemType()

Dim strApplicationMatchString :: strApplicationMatchString = lcase(trim("UniversalForwarder"))

Set objReg = Getx64RegistryProvider()
keyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
key64Path = "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"


' list out 32-bit applications on a 32-bit system, or 64-bit applications
' on a 64-bit system.
If RegKeyExists(objReg, HKLM, keyPath) Then
	objReg.EnumKey HKLM, keypath, arrSubKeys
	sResults = GetApplications(HKLM,keypath,arrSubKeys)
	If len(sResults)>1 Then
		if Is64 = True then
			DeleteRegistryKey "64","HKLM" & "\" & sResults
		else 
			DeleteRegistryKey "32","HKLM" & "\" & sResults
		end if
	end if
End If

'### IF PRODUCT KEY IS PRESENT, REMOVE IT
Dim ProductName
Const HKCR = &H80000000
strKeyPath = "Installer\Products"
Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
objReg.EnumKey HKCR, strKeyPath, arrSubKeys
On Error Resume Next
For Each key in arrSubKeys
	objReg.GetStringValue HKCR,strKeyPath & "\" & key,"ProductName", ProductName
	If InStr(LCase(ProductName),lcase("UniversalForwarder")) > 0 Then
		if Is64 = True then
			DeleteRegistryKey "64","HKCR" & "\" & strKeyPath & "\" & key
		else 
			DeleteRegistryKey "32","HKCR" & "\" & strKeyPath & "\" & key
		end if
	End If
Next
On Error Goto 0



Function GetApplications(HIVE, keypath,arrSubKeys)
	On Error Resume Next
	dim displayName, description
	For Each key in arrSubKeys
		objReg.GetStringValue HIVE,keyPath & "\" & key,"DisplayName", displayName
		objReg.GetStringValue HIVE,keyPath & "\" & key,"Description", description		
		If (InStr(LCase(displayName),strApplicationMatchString) > 0) or  (InStr(LCase(description),strApplicationMatchString) > 0) OR (InStr(LCase(key),strApplicationMatchString) > 0) Then
			GetApplications = keypath & "\" & key
		End If
	Next
	On Error Goto 0
End Function 'GetApplications

Sub DeleteRegistryKey(targetArch, targetKey)

	dim words, strHive, constHive, targetDefaultKey
	'Target architecture is needed since 64-bit machines have different branches for 32 and 64
	targetArch = LCase(targetArch)
	targetKey = targetKey

	If targetArch = "64" And Not(Is64) Then
		WScript.Echo "64-bit registry unavailable on 32-bit system"
		WScript.Quit
	End If

	'Split up strKey into the hive constant and the registry key
	words = Split(targetKey, "\")
	strHive = words(0)
	constHive = GetHiveConst(strHive)

	targetDefaultKey = Right(targetKey, Len(targetKey) - Len(strHive) -1)
	
	If strHive = "HKEY_USERS" Then
		' go through each User's hive
		Dim arrSubKeys, strUserKey
		objReg.EnumKey constHive, "", arrSubKeys
		For Each strUserKey In arrSubKeys
			If Not InStr(strUserKey,"_Classes") > 0 Then ' ignore _Classes entries
				DeleteKey64or32orBoth objReg, targetArch, strUserKey & "\", targetDefaultKey, strHive, constHive
			End If
		Next
	Else ' was another hive
		DeleteKey64or32orBoth objReg, targetArch, "", targetDefaultKey, strHive, constHive
	End If	

	
End Sub

Function DeleteKey64or32orBoth(objReg, targetArch, targetPreFix, targetKey, strHive, constHive)
	Dim targetWowKey
	targetWowKey = targetKey
	'Catch the 32-bit entries for any 64-bit machines
	If Is64 Then
		If targetArch = "32" Or targetArch = "both" Then
			WScript.Echo "is64, but deleting 32.  need to check for software/ and add wow6432node"
		
			If Left(LCase(targetWowKey), Len("software\")) = "software\" Then
				'need to insert wow6432node
				targetWowKey = "software\wow6432node\" & Right(targetWowKey, Len(targetWowKey) - Len("software\"))
			End If
			
			If targetWowKey <> targetKey Then
				'Catch Wow6432Node keys on 64-bit machines, if necessary
				DeleteKey objReg, constHive, targetPreFix & targetWowKey, targetArch, strHive
			Else
				' Deleting a 64-bit value somewhere which is not under the Software key
				DeleteKey objReg, constHive, targetPreFix & targetKey, targetArch, strHive
			End If
		End If
		
		If targetArch = "64" Or targetArch = "both" Then
			'Catch "64" and "both" for 64-bit machines
			DeleteKey objReg, constHive, targetPreFix & targetKey, targetArch, strHive
		End If
	Else
		'Catch "32" and "both" for 32-bit machines, "64" on 32-bit machines already ruled out with Quit
		DeleteKey objReg, constHive, targetPreFix & targetKey, targetArch, strHive
	End If
End Function ' DeleteKey64or32orBoth

Function DeleteKey(ojReg, constHive, targetKey, targetArch, strHive)
'	objReg.DeleteKey constHive, targetKey
	DeleteSubkeys constHive, targetKey
	
	If RegKeyExists(objReg, constHive, targetKey) Then
		WScript.Echo "Unable to delete key: " & targetKey
	Else
		WScript.Echo "Key deleted: " & targetKey
	End If
End Function

Function GetHiveConst(hive)
	Const HKEY_CLASSES_ROOT   = &H80000000
	Const HKEY_CURRENT_USER   = &H80000001
	Const HKEY_LOCAL_MACHINE  = &H80000002
	Const HKEY_USERS          = &H80000003

	Select Case UCase(hive)
		Case "HKLM"
			GetHiveConst = HKEY_LOCAL_MACHINE
		Case "HKEY_LOCAL_MACHINE"
			GetHiveConst = HKEY_LOCAL_MACHINE
		Case "HKCR"
			GetHiveConst = HKEY_CLASSES_ROOT
		Case "HKEY_CLASSES_ROOT"
			GetHiveConst = HKEY_CLASSES_ROOT
		Case "HKEY_CURRENT_USER"
			GetHiveConst = HKEY_CURRENT_USER
		Case "HKEY_USERS"
			GetHiveConst = HKEY_USERS
	End Select
	
	If IsEmpty(GetHiveConst) Then
		WScript.Echo "Invalid registry hive: " & hive
		WScript.Quit
	End If
End Function

Function Is64 
	Dim objWMIService, colItems, objItem
	Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
	Set colItems = objWMIService.ExecQuery("Select SystemType from Win32_ComputerSystem")    
	For Each objItem In colItems
		If InStr(LCase(objItem.SystemType), "x64") > 0 Then
			Is64 = True
		Else
			Is64 = False
		End If
	Next
End Function




''' ---- Fix Function definition ---- '''
Function x64Fix
' This is a function which should be called before calling any vbscript run by 
' the Tanium client that needs 64-bit registry or filesystem access.
' It's for when we need to catch if a machine has 64-bit windows
' and is running in a 32-bit environment.
'  
' In this case, we will re-launch the sensor in 64-bit mode.
' If it's already in 64-bit mode on a 64-bit OS, it does nothing and the sensor 
' continues on
    
    Const WINDOWSDIR = 0
    Const HKLM = &h80000002
    
    Dim objShell: Set objShell = CreateObject("WScript.Shell")
    Dim objFSO: Set objFSO = CreateObject("Scripting.FileSystemObject")
    Dim objSysEnv: Set objSysEnv = objShell.Environment("PROCESS")
    Dim objReg, objArgs, objExec
    Dim strOriginalArgs, strArg, strX64cscriptPath, strMkLink
    Dim strProgramFilesX86, strProgramFiles, strLaunchCommand
    Dim strKeyPath, strTaniumPath, strWinDir
    Dim b32BitInX64OS

    b32BitInX64OS = false

    ' we'll need these program files strings to check if we're in a 32-bit environment
    ' on a pre-vista 64-bit OS (if no sysnative alias functionality) later
    strProgramFiles = objSysEnv("ProgramFiles")
    strProgramFilesX86 = objSysEnv("ProgramFiles(x86)")
    ' WScript.Echo "Are the program files the same?: " & (LCase(strProgramFiles) = LCase(strProgramFilesX86))
    
    ' The windows directory is retrieved this way:
    strWinDir = objFso.GetSpecialFolder(WINDOWSDIR)
    'WScript.Echo "Windir: " & strWinDir
    
    ' Now we determine a cscript path for 64-bit windows that works every time
    ' The trick is that for x64 XP and 2003, there's no sysnative to use.
    ' The workaround is to do an NTFS junction point that points to the
    ' c:\Windows\System32 folder.  Then we call 64-bit cscript from there.
    ' However, there is a hotfix for 2003 x64 and XP x64 which will enable
    ' the sysnative functionality.  The customer must either have linkd.exe
    ' from the 2003 resource kit, or the hotfix installed.  Both are freely available.
    ' The hotfix URL is http://support.microsoft.com/kb/942589
    ' The URL For the resource kit is http://www.microsoft.com/download/en/details.aspx?id=17657
    ' linkd.exe is the only required tool and must be in the machine's global path.

    If objFSO.FileExists(strWinDir & "\sysnative\cscript.exe") Then
        strX64cscriptPath = strWinDir & "\sysnative\cscript.exe"
        ' WScript.Echo "Sysnative alias works, we're 32-bit mode on 64-bit vista+ or 2003/xp with hotfix"
        ' This is the easy case with sysnative
        b32BitInX64OS = True
    End If
    If Not b32BitInX64OS And objFSO.FolderExists(strWinDir & "\SysWow64") And (LCase(strProgramFiles) = LCase(strProgramFilesX86)) Then
        ' This is the more difficult case to execute.  We need to test if we're using
        ' 64-bit windows 2003 or XP but we're running in a 32-bit mode.
        ' Only then should we relaunch with the 64-bit cscript.
        
        ' If we don't accurately test 32-bit environment in 64-bit OS
        ' This code will call itself over and over forever.
        
        ' We will test for this case by checking whether %programfiles% is equal to
        ' %programfiles(x86)% - something that's only true in 64-bit windows while
        ' in a 32-bit environment
    
        ' WScript.Echo "We are in 32-bit mode on a 64-bit machine"
        ' linkd.exe (from 2003 resource kit) must be in the machine's path.
        
        strMkLink = "linkd " & Chr(34) & strWinDir & "\System64" & Chr(34) & " " & Chr(34) & strWinDir & "\System32" & Chr(34)
        strX64cscriptPath = strWinDir & "\System64\cscript.exe"
        ' WScript.Echo "Link Command is: " & strMkLink
        ' WScript.Echo "And the path to cscript is now: " & strX64cscriptPath
        On Error Resume Next ' the mklink command could fail if linkd is not in the path
        ' the safest place to put linkd.exe is in the resource kit directory
        ' reskit installer adds to path automatically
        ' or in c:\Windows if you want to distribute just that tool
        
        If Not objFSO.FileExists(strX64cscriptPath) Then
            ' WScript.Echo "Running mklink" 
            ' without the wait to completion, the next line fails.
            objShell.Run strMkLink, 0, true
        End If
        On Error GoTo 0 ' turn error handling off
        If Not objFSO.FileExists(strX64cscriptPath) Then
            ' if that cscript doesn't exist, the link creation didn't work
            ' and we must quit the function now to avoid a loop situation
            ' WScript.Echo "Cannot find " & strX64cscriptPath & " so we must exit this function and continue on"
            ' clean up
            Set objShell = Nothing
            Set objFSO = Nothing
            Set objSysEnv = Nothing
            Exit Function
        Else
            ' the junction worked, it's safe to relaunch            
            b32BitInX64OS = True
        End If
    End If
    If Not b32BitInX64OS Then
        ' clean up and leave function, we must already be in a 32-bit environment
        Set objShell = Nothing
        Set objFSO = Nothing
        Set objSysEnv = Nothing
        
        ' WScript.Echo "Cannot relaunch in 64-bit (perhaps already there)"
        ' important: If we're here because the client is broken, a sensor will
        ' run but potentially return incomplete or no values (old behavior)
        Exit Function
    End If
    
    ' So if we're here, we need to re-launch with 64-bit cscript.
    ' take the arguments to the sensor and re-pass them to itself in a 64-bit environment
    strOriginalArgs = ""
    Set objArgs = WScript.Arguments
    
    For Each strArg in objArgs
        strOriginalArgs = strOriginalArgs & " " & Chr(34) & strArg & Chr(34)
    Next
    ' after we're done, we have an unnecessary space in front of strOriginalArgs
    strOriginalArgs = LTrim(strOriginalArgs)
    
    ' If this is running as a sensor, we need to know the path of the tanium client
    strKeyPath = "Software\Tanium\Tanium Client"
    Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    objReg.GetStringValue HKLM,strKeyPath,"Path", strTaniumPath

    ' WScript.Echo "StrOriginalArgs is:" & strOriginalArgs
    If objFSO.FileExists(Wscript.ScriptFullName) Then
        strLaunchCommand = Chr(34) & Wscript.ScriptFullName & Chr(34) & " " & strOriginalArgs
        ' WScript.Echo "Script full path is: " & WScript.ScriptFullName
    Else
        ' the sensor itself will not work with ScriptFullName so we do this
        strLaunchCommand = Chr(34) & strTaniumPath & "\VB\" & WScript.ScriptName & chr(34) & " " & strOriginalArgs
    End If
    ' WScript.Echo "launch command is: " & strLaunchCommand

    ' Note:  There is a timeout limit here of 1 hour, as extra protection for runaway processes
    Set objExec = objShell.Exec(strX64cscriptPath & " //T:3600 " & strLaunchCommand)
    
    ' skipping the two lines and space after that look like
    ' Microsoft (R) Windows Script Host Version
    ' Copyright (C) Microsoft Corporation
    '
    objExec.StdOut.SkipLine
    objExec.StdOut.SkipLine
    objExec.StdOut.SkipLine

    ' sensor output is all about stdout, so catch the stdout of the relaunched
    ' sensor
    Wscript.Echo objExec.StdOut.ReadAll()
    
    ' critical - If we've relaunched, we must quit the script before anything else happens
    WScript.Quit
    ' Remember to call this function only at the very top
    
    ' Cleanup
    Set objReg = Nothing
    Set objArgs = Nothing
    Set objExec = Nothing
    Set objShell = Nothing
    Set objFSO = Nothing
    Set objSysEnv = Nothing
    Set objReg = Nothing
End Function 'x64Fix
'------------ INCLUDES after this line. Do not edit past this point -----
'- Begin file: i18n/UTF8Decode.vbs
'========================================
' UTF8Decode
'========================================
' Used to convert the UTF-8 style parameters passed from 
' the server to sensors in sensor parameters.
' This function should be used to safely pass non english input to sensors.
'-----
'-----
Function UTF8Decode(str)
    Dim arraylist(), strLen, i, sT, val, depth, sR
    Dim arraysize
    arraysize = 0
    strLen = Len(str)
    for i = 1 to strLen
        sT = mid(str, i, 1)
        if sT = "%" then
            if i + 2 <= strLen then
                Redim Preserve arraylist(arraysize + 1)
                arraylist(arraysize) = cbyte("&H" & mid(str, i + 1, 2))
                arraysize = arraysize + 1
                i = i + 2
            end if
        else
            Redim Preserve arraylist(arraysize + 1)
            arraylist(arraysize) = asc(sT)
            arraysize = arraysize + 1
        end if
    next
    depth = 0
    for i = 0 to arraysize - 1
		Dim mybyte
        mybyte = arraylist(i)
        if mybyte and &h80 then
            if (mybyte and &h40) = 0 then
                if depth = 0 then
                    Err.Raise 5
                end if
                val = val * 2 ^ 6 + (mybyte and &h3f)
                depth = depth - 1
                if depth = 0 then
                    sR = sR & chrw(val)
                    val = 0
                end if
            elseif (mybyte and &h20) = 0 then
                if depth > 0 then Err.Raise 5
                val = mybyte and &h1f
                depth = 1
            elseif (mybyte and &h10) = 0 then
                if depth > 0 then Err.Raise 5
                val = mybyte and &h0f
                depth = 2
            else
                Err.Raise 5
            end if
        else
            if depth > 0 then Err.Raise 5
            sR = sR & chrw(mybyte)
        end if
    next
    if depth > 0 then Err.Raise 5
    UTF8Decode = sR
End Function
'- End file: i18n/UTF8Decode.vbs



Sub DeleteSubkeys(HIVE, strKeyPath) 
	dim arrSubkeys, strSubkey
	objReg.EnumKey HIVE, strKeyPath, arrSubkeys
	If IsArray(arrSubkeys) Then 
		For Each strSubkey In arrSubkeys 
			DeleteSubkeys HIVE, strKeyPath & "\" & strSubkey 
		Next 
	End If 
	objReg.DeleteKey HIVE, strKeyPath 
End Sub

Function GetOSSystemType()
    ' Returns the best available registry provider:  32 bit on 32 bit systems, 64 bit on 64 bit systems
    Dim objWMIService, colItems, objItem, iArchType, objCtx, objLocator, objServices, objRegProv
    Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
    Set colItems = objWMIService.ExecQuery("Select SystemType from Win32_ComputerSystem")    
    For Each objItem In colItems
        If InStr(LCase(objItem.SystemType), "x64") > 0 Then
            iArchType = 64
        Else
            iArchType = 32
        End If
    Next
    GetOSSystemType = iArchType
End Function ' Getx64RegistryProvider


Function Getx64RegistryProvider
    ' Returns the best available registry provider:  32 bit on 32 bit systems, 64 bit on 64 bit systems
    Dim objWMIService, colItems, objItem, iArchType, objCtx, objLocator, objServices, objRegProv
    Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
    Set colItems = objWMIService.ExecQuery("Select SystemType from Win32_ComputerSystem")    
    For Each objItem In colItems
        If InStr(LCase(objItem.SystemType), "x64") > 0 Then
            iArchType = 64
        Else
            iArchType = 32
        End If
    Next
    
    Set objCtx = CreateObject("WbemScripting.SWbemNamedValueSet")
    objCtx.Add "__ProviderArchitecture", iArchType
    Set objLocator = CreateObject("Wbemscripting.SWbemLocator")
    Set objServices = objLocator.ConnectServer("","root\default","","",,,,objCtx)
    Set objRegProv = objServices.Get("StdRegProv")   
    
    Set Getx64RegistryProvider = objRegProv
End Function 


Function RegKeyExists(objReg, sHive, sRegKey)
	Dim aValueNames, aValueTypes
	If objReg.EnumValues(sHive, sRegKey, aValueNames, aValueTypes) = 0 Then
		RegKeyExists = True
	Else
		RegKeyExists = False
	End If
End Function
