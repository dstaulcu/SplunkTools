Option Explicit

Dim sExpectedVersion, sCurrentVersion
sExpectedVersion = "2.30.4.5"
sCurrentVersion = "1.2.3.4" 		' test - where version is lower [pass]
sCurrentVersion = "3.4.5.6"			' test - where version is higher than expected version [pass]
sCurrentVersion = ""				' test - where version is null [pass]
sCurrentVersion = "0.10.200.300"   	' test - where minor is long [pass]
sCurrentVersion = sExpectedVersion 	' test - where version is same [pass]
sCurrentVersion = "0.10.200.300"   	' test - where minor is long [pass]
sCurrentVersion = "200.3.400.500"	' test - where minor is long [pass]

wscript.echo IsVersionCompliant(sExpectedVersion,sCurrentVersion)

Function IsVersionCompliant(sExpectedVersion,sCurrentVersion)

	dim bDebug :: bDebug = True

	dim aExpectedVersion, sExpectedVersionPadded, i, sTemp, aCurrentVersion, sCurrentVersionPadded

	aExpectedVersion = split(sExpectedVersion,".")
	sExpectedVersionPadded = vbNullString
	sTemp = vbNullString

	' prepare the expected version for arithmatic comparison by padding each element with zeros
	for i=0 to ubound(aExpectedVersion) 
		sTemp = aExpectedVersion(i)
		sTemp = string((4-len(sTemp)),"0") & sTemp
		sExpectedVersionPadded = sExpectedVersionPadded & sTemp
	next 
	
	' prepare the detected version for arithmatic comparison by padding each element with zeros 
	if isnull(sCurrentVersion) or sCurrentVersion = "" then 
		sCurrentVersion = "0.0.0.0"
	end if
	
	aCurrentVersion = split(sCurrentVersion,".")
	sCurrentVersionPadded = vbNullString
	sTemp = vbNullString

	for i=0 to ubound(aCurrentVersion) 
		sTemp = aCurrentVersion(i)
		sTemp = string((4-len(sTemp)),"0") & sTemp
		sCurrentVersionPadded = sCurrentVersionPadded & sTemp
	next 
	
	sExpectedVersionPadded = abs(sExpectedVersionPadded)
	sCurrentVersionPadded = abs(sCurrentVersionPadded)
	

	if bDebug = True then 
		wscript.echo "sExpectedVersionPadded: " & sExpectedVersionPadded	
		wscript.echo "sCurrentVersionPadded: " & sCurrentVersionPadded
	end if
	
	if (sCurrentVersionPadded >= sExpectedVersionPadded) then
		IsVersionCompliant = True
		if bDebug = True then
			wscript.echo "Version compliant: " & sCurrentVersion & " >= " & sExpectedVersion
		end if
	else
		IsVersionCompliant = False
		if bDebug = True then 
			wscript.echo "Version not compliant: " & sCurrentVersion & " < " & sExpectedVersion	
		end if
	end if 

End Function
