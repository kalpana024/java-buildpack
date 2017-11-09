' @Author Divyesh Kumar
' @Purpose: Monitor Program provides stats related to IP HTTPS on Windows server.

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_Counters_IPHTTPSGlobal").objectSet
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh

Set objFSO = CreateObject("Scripting.FileSystemObject")
rem CAV_MON_HOME is used to get the working directory of cmon.
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
'Holds default sample interval 10 sec
const DEFAULT_INTERVAL = 10000
'Holds default test-run number = "NA"
const DEFAULT_TRNUM = "NA"
'Holds cmd argument
const DEFAULT_ARGS = ""
'Holds test-run partition number
const DEFAULT_PARTITION_NUM = 0
' Holds the vector 
Vectors = ""
' Holds unique vector id
vectorSeqId = -1
'Holds running test run file path refrence
runningTestFile = ""
'Holds arrayofVector with appending # at the end of vector name for filteration purpose
'Declaring the arrayOfVectorWithHash as dynamic array
Dim arrayOfVectorWithHash()

' Dictionary object holds vector name and corresponding unique number of sequence id.
' For e.g = Desktop,1 where vector name = Desktop and seqId = 1
Set vectorsSeqIdMap = CreateObject("Scripting.Dictionary")
'Holds commnad line argument passed to program
Set colNamedArguments = WScript.Arguments.Named

' Condition to check if command line argument contains "interval" argument
' If condition become true than it will set sample interval strInterval interval provided by the user else default 10 sec will be set 

If colNamedArguments.Exists("interval") Then
 strInterval = colNamedArguments.Item("interval")
Else
 strInterval = DEFAULT_INTERVAL
End If

'This condition will set test-run number if become true else default test-run number is "NA".

If colNamedArguments.Exists("trnum") Then
 strTrNum = colNamedArguments.Item("trnum")
Else
 strTrNum = DEFAULT_TRNUM
End If

'This condition will set partition number if become true else default partition number is "0".

If colNamedArguments.Exists("parnum") Then
 strTrParNum = colNamedArguments.Item("parnum")
Else
 strTrParNum = DEFAULT_PARTITION_NUM
End If

'Condition will check weather user specified name of comma seprated vector or not unde cmd /args:. 

If colNamedArguments.Exists("args") Then
 strArguments = colNamedArguments.Item("args")
Else
 strArguments = DEFAULT_ARGS
End If

' Condition to check weather user specified value of printLevel or not
' Default printLevel is data.

If colNamedArguments.Exists("printLevel") Then
 printType = colNamedArguments.Item("printLevel")
Else
 printType = "data"
End If

' Condition become true if user specified comma seprated vector names in arguments
' arrayOfvector of holds the vector names provided by the user
if NOT (strArguments = DEFAULT_ARGS) then
  arrayOfvector = Split(strArguments,",")
  'Initialize the arrayOfVectorWithHash vetcor array with size.
  ReDim arrayOfVectorWithHash(ubound(arrayOfvector))
  ' creating vector array with vectorName# for e.g vetcor name = w3wp than arrayOfVectorWithHash will contain w3wp
  For i = 0 to ubound(arrayOfvector) 
    arrayOfVectorWithHash(i) = arrayOfvector(i) & "#" 
  Next
End If

' If print level header it will print vector name and script will stop
if(printType = "header")  then
  printVector()	   	
  if (Vectors = "" ) then
    Wscript.Echo "Warning: No vectors."  
  else	
    Wscript.Echo Vectors & vbCrlf
  End If 
  WScript.Quit [0]
End If

' Function to generate a map for vector name and sequence id
' @return vectorSeqId

Function getVectorID(vectorName)
 if NOT (vectorsSeqIdMap.Exists(vectorName)) then
   vectorSeqId = vectorSeqId + 1
   vectorsSeqIdMap.Add vectorName , vectorSeqId
   getVectorID = vectorSeqId
 else
   getVectorID = vectorsSeqIdMap.Item(vectorName)
 End If
End Function		

'Function to print all generated vectors

Function printVector ()
  if (strArguments = DEFAULT_ARGS) then
    For Each objItem in colItems
      vectorName = objItem.Name
      if NOT (vectorName = "") then
        vectorName = Replace(vectorName, " ","_")
        Vectors = Vectors & getVectorID(vectorName) & ":" & vectorName & " "
      End If
    Next		
  else
    For Each objItem in colItems
      createSpecifiedVectorList(objItem)
    Next	   
  End If	 	 
End Function

' Function to create vector string for all user specified vectors

Function createSpecifiedVectorList(objItem)
  For i=0 to ubound(arrayOfvector)
    if(objItem.Name = arrayOfvector(i) OR  instr(1, objItem.Name , arrayOfVectorWithHash(i))) then
       vectorName = Replace(objItem.Name, " ","_")
       Vectors = Vectors & getVectorID(vectorName) & ":" & vectorName & " "
	Exit For
    End If  
  Next
End Function	

'hold running test run file path as varibale runningTestFile on the basis of condition on test-run number and partition number
' if test is not running in patrition mode than partition will be 0 and  test-run number is not default test-run number ("NA") than condition become True else false
If (strTrNum <> DEFAULT_TRNUM AND strTrParNum = 0) then
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum
else
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum & "_" & strTrParNum
End If 

' Print data 
do While True
'Checking TestRun Running File is exist or not
  if Not (strTrNum = DEFAULT_TRNUM) then
     If Not objFSO.FileExists(runningTestFile) Then 
       WScript.Quit [0]
     End If
  End If

  For Each objItem in colItems
    if(strArguments = DEFAULT_ARGS) then
      printData(objItem)
    else
      printDataForSpecificVectors(objItem)
    End if
  Next   
  Wscript.Sleep strInterval
  objRefresher.Refresh
Loop

' Function to print data

Function printData(objItem)
  dim vectorName
  if NOT (objItem.Name = "") then
    vectorName = Replace(objItem.Name, " ","_")
    Wscript.Echo getVectorID(vectorName) & ":" & vectorName & "|" & objItem.DropsNeighborresolutiontimeouts & " " & objItem.ErrorsAuthenticationErrors & " " & objItem.ErrorsReceiveerrorsontheserver & " " & objItem.ErrorsTransmiterrorsontheserver & " " & objItem.InTotalbytesreceived & " " & objItem.InTotalpacketsreceived & " " & objItem.OutTotalbytesforwarded & " " & objItem.OutTotalbytessent & " " & objItem.OutTotalpacketssent & " " & objItem.SessionsTotalsessions & vbCrlf
  End If
End Function

' Function to print data for user specified vector provided in arguments
Function printDataForSpecificVectors(objItem)
  For i = 0 to ubound(arrayOfvector)
    if( objItem.Name = arrayOfvector(i) OR instr(1, objItem.Name , arrayOfVectorWithHash(i))) then
      printData(objItem)
      Exit For
    End If
  Next
End Function