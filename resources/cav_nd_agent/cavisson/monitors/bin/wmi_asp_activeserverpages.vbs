strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_ASP_ActiveServerPages").objectSet
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh

Set objFSO = CreateObject("Scripting.FileSystemObject")
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
const DEFAULT_INTERVAL = 10000
const DEFAULT_TRNUM = "NA"
const DEFAULT_ARGS = ""
const DEFAULT_PARTITION_NUM = 0
'Holds running test run file path refrence
runningTestFile = ""

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

'hold running test run file path as varibale runningTestFile on the basis of condition on test-run number and partition number
' if test is not running in patrition mode than partition will be 0 and  test-run number is not default test-run number ("NA") than condition become True else false
If (strTrNum <> DEFAULT_TRNUM AND strTrParNum = 0) then
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum
else
  runningTestFile = CAV_MON_HOME & "\logs\running_tests\" & strTrNum & "_" & strTrParNum
End If 

'Wscript.Echo strArguments

do While True
'Checking TestRun Running File is exist or not
    if Not (strTrNum = DEFAULT_TRNUM) then
      If Not objFSO.FileExists(runningTestFile) Then 
        WScript.Quit [0]
      End If
    End If
    For Each objItem in colItems
        Wscript.Echo objItem.ErrorsPerSec & " " & objItem.RequestsPerSec & " " & objItem.RequestWaitTime & " " & objItem.SessionsCurrent & " " & objItem.TransactionsPerSec
        Wscript.Sleep strInterval
    objRefresher.Refresh
    Next
Loop
