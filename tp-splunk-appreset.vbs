Option Explicit

Dim objShell :: Set objShell = CreateObject("WScript.Shell")
Dim objFSO :: Set objFSO = CreateObject("Scripting.FileSystemObject")
Dim objFolder, colSubFolders, objSubfolder, strCurrentFolderName, intCurrentFolderAge, intYoungestFolderAge, strYoungestFolderName
Dim strSplunkProgramPath :: strSplunkProgramPath = "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe"
Dim strSplunkAppsPath :: strSplunkAppsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps"
Dim blnSomethingDeleted :: blnSomethingDeleted = False

Dim blnDebug :: blnDebug = True


If NOT objFSO.FileExists(strSplunkProgramPath) Then
    wscript.echo "Splunk program file does not exist."
	wscript.quit
End If

If NOT objFSO.FolderExists(strSplunkAppsPath) Then
    wscript.echo "Splunk apps folder does not exist."
	wscript.quit
End If

Set objFolder = objFSO.GetFolder(strSplunkAppsPath)
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
		' delete the folder
		blnSomethingDeleted = True
		if blnDebug = True then
			wscript.echo "Deleting folder with name:  " & objSubfolder.Name
		end if
		objSubfolder.delete
	end if
Next

if blnSomethingDeleted = True then 
	if blnDebug = True then
		wscript.echo "Restarting splunk. (no wait)"
	end if
	objShell.Run chr(34) & strSplunkProgramPath & chr(34) & " restart", 0, False
end if

