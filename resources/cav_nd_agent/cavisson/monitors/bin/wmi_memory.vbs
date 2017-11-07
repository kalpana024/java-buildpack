'------------------------------------------------------------------------------------------------------------------------
'  @author - Divyesh Kumar                                                                               
'  @Purpose - The Win32_PerfFormattedData_PerfOS_Memory raw performance data class provides The Memory performance object consists of counters that describe the behavior of physical and virtual memory on the computer. Physical memory is the amount of random access memory on the computer. Virtual memory consists of the space in physical memory and on disk. Many of the memory counters monitor paging, which is the movement of pages of code and data between disk and physical memory. Excessive paging, a symptom of a memory shortage, can cause delays which interfere with all system processes.
'  @Command For Counters - wmic path Win32_PerfFormattedData_PerfOS_Memory         
'  @Counters -  AvailableBytes  AvailableKBytes  AvailableMBytes  CacheBytes  CacheBytesPeak  CacheFaultsPersec  Caption  CommitLimit  CommittedBytes  DemandZeroFaultsPersec  Description  FreeAndZeroPageListBytes  FreeSystemPageTableEntries  Frequency_Object  Frequency_PerfTime  Frequency_Sys100NS  LongTermAverageStandbyCacheLifetimes  ModifiedPageListBytes  Name  PageFaultsPersec  PageReadsPersec  PagesInputPersec  PagesOutputPersec  PagesPersec  PageWritesPersec  PercentCommittedBytesInUse  PoolNonpagedAllocs  PoolNonpagedBytes  PoolPagedAllocs  PoolPagedBytes  PoolPagedResidentBytes  StandbyCacheCoreBytes  StandbyCacheNormalPriorityBytes  StandbyCacheReserveBytes  SystemCacheResidentBytes  SystemCodeResidentBytes  SystemCodeTotalBytes  SystemDriverResidentBytes  SystemDriverTotalBytes  Timestamp_Object  Timestamp_PerfTime  Timestamp_Sys100NS  TransitionFaultsPersec  TransitionPagesRePurposedPersec  WriteCopiesPersec                                                                                    
' @GDF - cm_win_memory_stats.gdf 
' Monitor Syntax :STANDARD_MONITOR QA_Tier>WindowsMachine QA_Tier>WindowsMachine MemoryStats
'-----------------------------------------------------------------------------------------------------------------------

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_PerfOS_Memory").objectSet
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh

Set objFSO = CreateObject("Scripting.FileSystemObject")

const DEFAULT_INTERVAL = 10000
const DEFAULT_TRNUM = "NA"
const DEFAULT_ARGS = ""
const DEFAULT_PARTITION_NUM = 0
const byteToMB = 1048576

Set colNamedArguments = WScript.Arguments.Named
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))

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
  runningTestFile =  CAV_MON_HOME & "\logs\running_tests\" & strTrNum & "_" & strTrParNum
End If 

' Print data 
do While True
'Checking TestRun Running File is exist or not
  If Not objFSO.FileExists(runningTestFile) Then 
    WScript.Quit [0]
  End If    
  
  For Each objItem in colItems
    Wscript.Echo objItem.AvailableMBytes & " " & Round((objItem.CacheBytes/byteToMB) ,3) & " " & Round((objItem.CacheBytesPeak/byteToMB),3) & " " & objItem.CacheFaultsPersec & " " & Round((objItem.CommitLimit/byteToMB),3) & " " & Round((objItem.CommittedBytes/byteToMB),3) & " " & objItem.DemandZeroFaultsPersec & " " & objItem.FreeSystemPageTableEntries & " " & objItem.PageFaultsPersec & " " & objItem.PageReadsPersec & " " & objItem.PagesInputPersec & " " & objItem.PagesOutputPersec & " " & objItem.PagesPersec & " " & objItem.PageWritesPersec & " " & objItem.PercentCommittedBytesInUse & " " & objItem.PoolNonpagedAllocs & " " & Round((objItem.PoolNonpagedBytes/byteToMB),3) & " " & objItem.PoolPagedAllocs & " " & Round((objItem.PoolPagedBytes/byteToMB),3) & " " & Round((objItem.PoolPagedResidentBytes/byteToMB),3) & " " & Round((objItem.SystemCacheResidentBytes/byteToMB),3) & " " & Round((objItem.SystemCodeResidentBytes/byteToMB),3) & " " & Round((objItem.SystemCodeTotalBytes/byteToMB),3) & " " & Round((objItem.SystemDriverResidentBytes/byteToMB),3) & " " & Round((objItem.SystemDriverTotalBytes/byteToMB),3) & " " & objItem.TransitionFaultsPersec & " " & objItem.TransitionPagesRePurposedPersec & " " & objItem.WriteCopiesPersec & " " & Round((objItem.FreeAndZeroPageListBytes/byteToMB),3) & " " & Round((objItem.ModifiedPageListBytes/byteToMB),3) & " " & Round((objItem.StandbyCacheCoreBytes/byteToMB),3) & " " & Round((objItem.StandbyCacheNormalPriorityBytes/byteToMB),3) & " " & Round((objItem.StandbyCacheReserveBytes/byteToMB),3) & vbCrlf
    Next
    Wscript.Sleep strInterval
    objRefresher.Refresh
  Loop
