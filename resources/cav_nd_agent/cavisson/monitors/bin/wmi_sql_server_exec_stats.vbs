Rem -----------------------------------------------------------------------------------------------------------------
Rem @Author - Nishank Tyagi
Rem @Description - This class provides info about List of classes with DTCcalls local property in ROOT\CIMV2 namespace.
Rem @GDF - cm_win_sql_server_exec_stats.gdf
Rem Mon_Syntax - STANDARD_MONITOR QA_Tier>WINTESTENV QA_Tier>WINTESTENV SQLServerExecutionStats
Rem--------------------------------------------------------------------------------------------------------------------

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_MSSQLSERVER_SQLServerExecStatistics").objectSet
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh

Set objFSO = CreateObject("Scripting.FileSystemObject")
rem CAV_MON_HOME is used to get the working directory of cmon.
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
const DEFAULT_INTERVAL = 10000
const DEFAULT_TRNUM = "NA"
const DEFAULT_ARGS = ""
const DEFAULT_PARTITION_NUM = 0
Vectors = ""

Dim Vector_Array
Dim DataType_Array
Vector_Array = Array("DistributedQuery", "DTCcalls", "ExtendedProcedures", "OLEDBcalls")
DataType_Array = Array("Average execution time (ms)", "Cumulative execution time (ms) per second", "Execs in progress", "Execs started per second")

Dim arrOfData(4,4)

Set colNamedArguments = WScript.Arguments.Named

'strInterval = colNamedArguments.Item("interval")
'Wscript.Echo strInterval

If colNamedArguments.Exists("interval") Then
 strInterval = colNamedArguments.Item("interval")
Else
 strInterval = DEFAULT_INTERVAL
End If

'Wscript.Echo strInterval

If colNamedArguments.Exists("trnum") Then
 strTrNum = colNamedArguments.Item("trnum")
Else
 strTrNum = DEFAULT_TRNUM
End If

'Wscript.Echo strTrNum

If colNamedArguments.Exists("parnum") Then
 strTrParNum = colNamedArguments.Item("parnum")
Else
 strTrParNum = DEFAULT_PARTITION_NUM
End If

'Wscript.Echo strTrParNum

If colNamedArguments.Exists("args") Then
 strArguments = colNamedArguments.Item("args")
Else
 strArguments = DEFAULT_ARGS
End If

If colNamedArguments.Exists("printLevel") Then
  printType = colNamedArguments.Item("printLevel")
Else
  printType = "data"
End If

if NOT (strArguments = DEFAULT_ARGS) then
  arrayOfvector = Split(strArguments,",")
End If

if(printType = "header")  then
  printVector()	   	
  Wscript.Echo Vectors & vbCrlf
  WScript.Quit [0]	
End If

Function printVector ()  
  if (strArguments = DEFAULT_ARGS) then
    For i=0 to ubound(Vector_Array)
      Vectors = Vectors & i & ":" & Vector_Array(i) & " " 
    Next			   
  End If	 	 
End Function	

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
    storeAllExecQueryData(objItem)
  Next   
  
  printData()
  
  Wscript.Sleep strInterval
  objRefresher.Refresh
Loop

'From Perf Mon we are getting data as:-
' ---- Header ----------------  = ---- data -------
' Average execution time (ms) = DistributedQuery, DTCcalls, ExtendedProcedures, OLEDBcalls
' Cumulative execution time (ms) per second = DistributedQuery, DTCcalls, ExtendedProcedures, OLEDBcalls
' Execs in progress = DistributedQuery, DTCcalls, ExtendedProcedures, OLEDBcalls
' Execs started per second = DistributedQuery, DTCcalls, ExtendedProcedures, OLEDBcalls
'
' ---------------------------------------------------------------------------------------
' Here we need to changes Header and data as: -
' ---- Header ----------------  = ---- data -------
' DistributedQuery = Average execution time (ms), Cumulative execution time (ms) per second, Execs in progress, Execs started per second
' DTCcalls = Average execution time (ms), Cumulative execution time (ms) per second, Execs in progress, Execs started per second
' ExtendedProcedures = Average execution time (ms), Cumulative execution time (ms) per second, Execs in progress, Execs started per second
' OLEDBcalls = Average execution time (ms), Cumulative execution time (ms) per second, Execs in progress, Execs started per second
'
'
' To do this here we have arrOfData 2D array to store header and data info.
' arrOfData(i,0) : - Here for each DataType_Array(i) we are storing every query info. 

   
Function storeAllExecQueryData(objItem)
  For i =0 to ubound(DataType_Array)
    if(objItem.Name = DataType_Array(i)) then
      arrOfData(i,0) = objItem.DistributedQuery
      arrOfData(i,1) = objItem.DTCcalls
      arrOfData(i,2) = objItem.ExtendedProcedures
      arrOfData(i,3) = objItem.OLEDBcalls
    End If
  Next
End Function

'Here iterating the Vector_Array with arrOfData as:-
' for j =0 
' Vector_Array(0) : - DistributedQuery (Vector)
'-----------------------------------------
' arrOfData(0, 0) :-  Average execution time (ms) of DistributedQuery
' arrOfData(1, 0) :- Cumulative execution time (ms) per second of DistributedQuery
' arrOfData(2, 0) :- Execs in progress of DistributedQuery
' arrOfData(3, 0) :- Execs started per second of DistributedQuery

Function printData()
   For j =0 to ubound(Vector_Array)
     Wscript.Echo j & ":" & Vector_Array(j) & "|" & arrOfData(0,j) & " " & arrOfData(1,j) & " " & arrOfData(2,j) & " " & arrOfData(3,j) & vbCrlf
   Next
End Function

