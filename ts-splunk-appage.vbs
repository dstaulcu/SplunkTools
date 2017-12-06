Option Explicit

Dim objFSO :: Set objFSO = CreateObject("Scripting.FileSystemObject")
Dim objFolder, colSubFolders, objSubfolder, strCurrentFolderName, intCurrentFolderAge, intYoungestFolderAge, strYoungestFolderName

Dim blnDebug :: blnDebug = False

Dim strFolderOfInterest :: strFolderOfInterest = "C:\Program Files\SplunkUniversalForwarder\etc\apps"

If NOT objFSO.FolderExists(strFolderOfInterest) Then
    wscript.echo "Splunk apps folder does not exist."
	wscript.quit
End If

Set objFolder = objFSO.GetFolder(strFolderOfInterest)
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
		intCurrentFolderAge = datediff("s",objSubfolder.DateLastModified,Now)
		if (intYoungestFolderAge = "" Or intYoungestFolderAge > intCurrentFolderAge) Then
			intYoungestFolderAge = intCurrentFolderAge
			strYoungestFolderName = strCurrentFolderName
		end if
	end if
Next

' if we got this far, check to see if folders were found and report on status
if intYoungestFolderAge >= 0 then 
	' convert age from seconds to days
	intYoungestFolderAge = round(intYoungestFolderAge/86400,0)
	if blnDebug = True Then 
		wscript.echo "The most recent splunk app [" & strYoungestFolderName & "] is [" & intYoungestFolderAge & "] days old."		
	end if
	wscript.echo intYoungestFolderAge
else 
	wscript.Echo "Splunk apps folder does not contain custom apps."		
end if
	