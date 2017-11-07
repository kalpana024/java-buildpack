Rem Represent local computer
strComputer = "."

const DEFAULT_TIER = ""
const DEFAULT_CONTROLLER = ""
const DEFAULT_SERVER=""
const DEFAULT_INSTANCE=""

Set colNamedArguments = WScript.Arguments.Named
Set objFSO=CreateObject("Scripting.FileSystemObject")
rem CAV_MON_HOME is used to get the working directory of cmon.

CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))

If colNamedArguments.Exists("TIER") Then
  Tier = colNamedArguments.Item("TIER")
Else
  Tier = DEFAULT_TIER
End If


If colNamedArguments.Exists("INSTANCE") Then
  Instance = colNamedArguments.Item("INSTANCE")
Else
  Instance = DEFAULT_INSTANCE
End If

If colNamedArguments.Exists("SERVER") Then
  Server = colNamedArguments.Item("SERVER")
Else
  Server = DEFAULT_SERVER
End If

If colNamedArguments.Exists("CONTROLLER") Then
  Controller = colNamedArguments.Item("CONTROLLER")
Else
  Controller = DEFAULT_CONTROLLER
End If

call updateCmonConfiguration()

call updateNDSettings()

Function updateCmonConfiguration()
  
  configFile = CAV_MON_HOME & "\sys\cmon.env"

  Set keyValueMap = CreateObject("Scripting.Dictionary")

  call readFileInMap (configFile, keyValueMap)

  call updateMapWithKeyword(keyValueMap, "CONTROLLER", Controller)

  call updateMapWithKeyword(keyValueMap, "TIER", Tier)

  call updateMapWithKeyword(keyValueMap, "SERVER", Server)

  call writeFileFromMap(configFile, keyValueMap)

End Function

Function updateNDSettings()

  nddirPath = objFSO.GetParentFolderName(objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))) & "\netdiagnostics\config\"
 
  If objFSO.FolderExists(nddirPath) Then
    ndSettingFilePath = nddirPath & "\ndsettings_1.conf"
	set SettingValueMap = CreateObject("Scripting.Dictionary")
	call readFileInMap (ndSettingFilePath, SettingValueMap)
	
	If Controller <> "" then
	  splitArrayData = Split(Controller,":")
	  host = ""
	  port = ""
	  For i = 0 to ubound(splitArrayData) 
        If i = 0 then
	      host = splitArrayData(i)
		  call updateMapWithKeyword(SettingValueMap, "ndcHost", host)
	    ElseIf i = 1 then
		  port = splitArrayData(i)
		  call updateMapWithKeyword(SettingValueMap, "ndcPort", port)
		Else
		  WScript.Echo "Invalid property - " & splitArrayData(i)
        End If
	  Next
	End If
	
	call updateMapWithKeyword(SettingValueMap, "tier", Tier)
	call updateMapWithKeyword(SettingValueMap, "server", Server)
	call updateMapWithKeyword(SettingValueMap, "instance", Instance)
	
	call writeFileFromMap(ndSettingFilePath, SettingValueMap)
  Else 
    WScript.Echo "Netdiagnostics is not installed."
  End If
 
End Function
 
Function writeFileFromMap(filePath, ValueMap)
  Set objFile = objFSO.CreateTextFile(filePath,True)
  mapItem = ValueMap.Keys( )
  For Each strItem in mapItem
    value = ValueMap.Item(strItem)
    If value = "" then
      objFile.Write strItem & vbCrLf
    Else 
	  objFile.Write strItem & "=" & value & vbCrLf
    End If
  Next
End Function

Function readFileInMap(filePath, ValueMap)
  
  'Reading cmon.env if exist
  If objFSO.FileExists(filePath) Then
    Set objFile = objFSO.OpenTextFile(filePath)
    Do Until objFile.AtEndOfStream
      strLine= objFile.ReadLine
	  dataArray = Split(strLine,"=")
	  key = ""
	  value = ""
	  For i = 0 to ubound(dataArray) 
        If i = 0 then
	      key = dataArray(i)
	    Else
	      If value = "" then
		    value = dataArray(i)
		  Else
	        value = value & "=" & dataArray(i)
	      End If
        End If
	  Next
	  ValueMap.Add key , value
    Loop
    objFile.Close
  End If
End Function

Function updateMapWithKeyword(mapObject, key , value)
  If value <> "" then
   if NOT (mapObject.Exists(key)) then
     mapObject.Add key , value
   else
     mapObject.remove(key)
     mapObject.Add key , value
    End If
  End If
End Function

























