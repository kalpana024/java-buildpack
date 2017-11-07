Rem---------------------------------------------------------------------------------------------------------------------
Rem @Author - divyesh kumar
Rem @Description - This script Collects statistics associated with the database server access methods.
Rem @GDF - cm_win_mssql_db_accessmethods.gdf
Rem @Monitor Syntax - STANDARD_MONITOR QA_Tier>WINTESTENV QA_Tier>WINTESTENV MSSQLDBAccessMethodsStats
Rem---------------------------------------------------------------------------------------------------------------------

Rem Represent local computer
strComputer = "."
Rem WMI tasks object to obtain information about services, including dependent or antecedent services running on computer.
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")	
Rem The SWbemRefresher object is a container object that can refresh the data for all the objects that are added to
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
' Object to holds WMI reference class object
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_MSSQLSTOREDB_MSSQLSTOREDBAccessMethods").objectSet
objRefresher.Refresh
Rem In win2003 its giving blank line b'coz it calling null values.
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
Rem Holds commnad line argument passed to program
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
  runningTestFile =CAV_MON_HOME & "\logs\running_tests\" & strTrNum
else
  runningTestFile =CAV_MON_HOME & "\logs\running_tests\" & strTrNum & "_" & strTrParNum
End If

Rem Print data 
do While True
Rem Checking TestRun Running File is exist or not
  If Not objFSO.FileExists(runningTestFile) Then 
    WScript.Quit [0]
  End If
  For Each objItem in colItems
      printData(objItem)   
  Next   
  Wscript.Sleep strInterval
  objRefresher.Refresh
Loop

Function printData(objItem)
  Wscript.Echo objItem.FullScansPersec & " " & objItem.PageSplitsPersec & " " & objItem.TableLockEscalationsPersec & " " & objItem.FreeSpaceScansPersec & " " & objItem.IndexSearchesPersec & " " & objItem.ScanPointRevalidationsPersec & " " & objItem.WorkfilesCreatedPersec & " " & objItem.WorktablesCreatedPersec & vbCrlf
End Function


