Rem---------------------------------------------------------------------------------------------------------------
Rem @Author - Divyesh/Nishank Tyagi
Rem @GDF - cm_win_sql_server_buffer_manager.gdf
Rem @Description - This script is used to get metrics about read, write, free page etc..
Rem @Monitor Syntax - STANDARD_MONITOR QA_Tier>WINTESTENV QA_Tier>WINTESTENV SQLServerBufferManager
Rem --------------------------------------------------------------------------------------------------------------------

Rem Represent local computer
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_MSSQLSERVER_SQLServerBufferManager").objectSet
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh
Rem Hold file system object
Set objFSO = CreateObject("Scripting.FileSystemObject")
rem CAV_MON_HOME is used to get the working directory of cmon.
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
Rem Holds default sample interval 10 sec
const DEFAULT_INTERVAL = 10000
Rem Holds default test-run number = "NA"
const DEFAULT_TRNUM = "NA"
Rem Holds monitor arguments
const DEFAULT_ARGS = ""
Rem Holds test-run partition number
const DEFAULT_PARTITION_NUM = 0
Rem Holds running test run file path refrence
runningTestFile = ""
Rem Holds command line argument passed to program
Set colNamedArguments = WScript.Arguments.Named

Rem Condition to check if command line argument contains "interval" argument
Rem If condition become true than it will set sample interval strInterval interval provided by the user else default 10 sec will be set
If colNamedArguments.Exists("interval") Then
 strInterval = colNamedArguments.Item("interval")
Else
 strInterval = DEFAULT_INTERVAL
End If

Rem This condition will set test-run number if become true else default test-run number is "NA".

If colNamedArguments.Exists("trnum") Then
 strTrNum = colNamedArguments.Item("trnum")
Else
 strTrNum = DEFAULT_TRNUM
End If

Rem This condition will set partition number if become true else default partition number is "0".

If colNamedArguments.Exists("parnum") Then
 strTrParNum = colNamedArguments.Item("parnum")
Else
 strTrParNum = DEFAULT_PARTITION_NUM
End If


Rem Condition will check weather user specified name of comma seprated vector or not. 

If colNamedArguments.Exists("args") Then
 strArguments = colNamedArguments.Item("args")
Else
 strArguments = DEFAULT_ARGS
End If

Rem hold running test run file path as varibale runningTestFile on the basis of condition on test-run number and partition number
Rem if test is not running in patrition mode than partition will be 0 and  test-run number is not default test-run number ("NA") than condition become True else false

If (strTrNum <> DEFAULT_TRNUM AND strTrParNum = 0) then
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum
else
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum & "_" & strTrParNum
End If 

Rem Print data 
do While True
Rem Checking TestRun Running File is exist or not
 If Not (strTrNum = DEFAULT_TRNUM) Then
  If Not objFSO.FileExists(runningTestFile) Then 
    WScript.Quit [0]
  End If
 End If
 
  For Each objItem in colItems
      printData(objItem)
  Next   
  Wscript.Sleep strInterval
  objRefresher.Refresh
Loop
Rem Function to print data
Function printData(objItem)
  Wscript.Echo objItem.Buffercachehitratio & " " & objItem.CheckpointpagesPersec & " " & objItem.Databasepages & " " & objItem.FreeliststallsPersec & " " & objItem.LazywritesPersec  & " " & objItem.Pagelifeexpectancy & " " & objItem.PagelookupsPersec  & " " & objItem.PagereadsPersec   & " " & objItem.PagewritesPersec & " " & objItem.ReadaheadpagesPersec  & " " & objItem.Targetpages & vbCrlf  
End Function
