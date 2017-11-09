Rem ------------------------------------------------------------------------------------------------------------------
Rem @Author  : Divyesh Kumar
Rem @Purpose : The Processor performance object consists of counters that measure aspects of processor activity. The processor is the part of the computer that performs arithmetic and logical computations, initiates operations on peripherals, and runs the threads of processes. A computer can have multiple processors. The processor object represents each processor as an instance of the object
Rem @GDF    : cm_win_processor_stats.gdf
Rem @Counter : C1TransitionsPersec  C2TransitionsPersec  C3TransitionsPersec  Caption  Description  DPCRate  DPCsQueuedPersec  Frequency_Object  Frequency_PerfTime  Frequency_Sys100NS  InterruptsPersec  Name    PercentC1Time  PercentC2Time  PercentC3Time  PercentDPCTime  PercentIdleTime  PercentInterruptTime  PercentPrivilegedTime  PercentProcessorTime  PercentUserTime  Timestamp_Object  Timestamp_PerfTime  Timestamp_Sys100NS
Rem @Command To Check Counters : wmic path Win32_PerfFormattedData_PerfOS_Processor
Rem @Monitor Syntax : STANDARD_MONITOR TierName>Server TierName>ServerName>Instance StandardMonitorName
Rem To get All Processor Data : STANDARD_MONITOR QA_Tier>WindowsMachine QA_Tier>WindowsMachine>QA-INST ProcessorStats
Rem To get Specific Processor Data : STANDARD_MONITOR QA_Tier>WindowsMachine QA_Tier>WindowsMachine>QA-INST ProcessorStats /args:CPU0,CPU1,CPU2
Rem --------------------------------------------------------------------------------------------------------------------

Rem Represent local computer
strComputer = "."
rem WMI tasks object to obtain information about services, including dependent or antecedent services running on computer.
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")	
Rem The SWbemRefresher object is a container object that can refresh the data for all the objects that are added to
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Rem Object to holds WMI reference class object of processor class in perfmon
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_PerfFormattedData_PerfOS_Processor").objectSet
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
Rem Holds the vector 
Vectors = ""
Rem Holds unique vector id
vectorSeqId = -1
Rem Holds running test run file path refrence
runningTestFile = ""
Rem Holds arrayofVector with appending # at the end of vector name for filteration purpose
Rem Declaring the arrayOfVectorWithHash as dynamic array
Dim arrayOfVectorWithHash()
Rem Dictionary object holds vector name and corresponding unique number of sequence id.
Rem For e.g = Desktop,1 where vector name = Desktop and seqId = 1
Set vectorsSeqIdMap = CreateObject("Scripting.Dictionary")

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

Rem Condition to check weather user specified value of printLevel or not
Rem Default printLevel is data.

If colNamedArguments.Exists("printLevel") Then
 printType = colNamedArguments.Item("printLevel")
Else
 printType = "data"
End If

Rem Condition become true if user specified comma seprated vector names in arguments
Rem arrayOfvector of holds the vector names provided by the user

if NOT (strArguments = DEFAULT_ARGS) then
  arrayOfvector = Split(strArguments,",")  
  Rem Initialize the arrayOfVectorWithHash vetcor array with size.
  ReDim arrayOfVectorWithHash(ubound(arrayOfvector))
  Rem creating vector array with vectorName# for e.g vetcor name = w3wp than arrayOfVectorWithHash will contain w3wp
  For i = 0 to ubound(arrayOfvector)
    Rem removing all CPU named string from user defined vector name so that vector name can be exactly matched with perfmon processor name
    arrayOfvector(i) = Replace(arrayOfvector(i),"CPU","")  
    arrayOfVectorWithHash(i) = arrayOfvector(i) & "#" 
  Next
End If

Rem If print level header it will print vector name and script will stop

if(printType = "header")  then
  printVector()	
  if (Vectors = "" ) then
    Wscript.Echo "Warning: No vectors."  
  else	
    Wscript.Echo Vectors & vbCrlf
  End If     	
  WScript.Quit [0]
End If

Rem Function to generate a map for vector name and sequence id
Rem @return vectorSeqId

Function getVectorID(vectorName)
 if NOT (vectorsSeqIdMap.Exists(vectorName)) then
   vectorSeqId = vectorSeqId + 1
   vectorsSeqIdMap.Add vectorName , vectorSeqId
   getVectorID = vectorSeqId
 else
   getVectorID = vectorsSeqIdMap.Item(vectorName)
 End If
End Function		

Rem Function to print all generated vectors

Function printVector ()
  if (strArguments = DEFAULT_ARGS) then
    For Each objItem in colItems
      vectorName = objItem.Name
      if NOT (vectorName = "") then
        vectorName = Replace(vectorName, " ","_")
		vectorName = "CPU" & vectorName
        Vectors = Vectors & getVectorID(vectorName) & ":" & vectorName & " "
      End If
    Next		
  else
    For Each objItem in colItems
      createSpecifiedVectorList(objItem)
    Next	   
  End If	 	 
End Function

Rem Function to create vector string for all user specified vectors

Function createSpecifiedVectorList(objItem)
  For i=0 to ubound(arrayOfvector)
    if(objItem.Name = arrayOfvector(i) OR  instr(1, objItem.Name , arrayOfVectorWithHash(i))) then
       vectorName = Replace(objItem.Name, " ","_")
	   vectorName = "CPU" & vectorName
       Vectors = Vectors & getVectorID(vectorName) & ":" & vectorName & " "
	Exit For
    End If  
  Next
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
  If Not objFSO.FileExists(runningTestFile) Then 
    WScript.Quit [0]
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

Rem Function to print data

Function printData(objItem)
  dim vectorName
  if NOT (objItem.Name = "") then
    vectorName = Replace(objItem.Name, " ","_")
	vectorName = "CPU" & vectorName
    Wscript.Echo getVectorID(vectorName) & ":" & vectorName & "|" & objItem.DPCRate & " " & objItem.DPCsQueuedPersec & " " & objItem.InterruptsPersec & " " & objItem.PercentDPCTime & " " & objItem.PercentIdleTime & " " & objItem.PercentInterruptTime & " " & objItem.PercentPrivilegedTime & " " & objItem.PercentProcessorTime & " " & objItem.PercentUserTime & vbCrlf
  End If
End Function

Rem Function to print data for user specified vector provided in arguments

Function printDataForSpecificVectors(objItem)
  For i = 0 to ubound(arrayOfvector)
    if( objItem.Name = arrayOfvector(i) OR instr(1, objItem.Name , arrayOfVectorWithHash(i))) then
      printData(objItem)
      Exit For
    End If
  Next
End Function
