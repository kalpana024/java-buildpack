'------------------------------------------------------------------------------------------------------------------------                          
'  @Author - Richa 
'  @Purpose - The Win32_perfformatteddata_perfproc_thread raw performance data class provides raw data from performance counters that monitor running application  program and system processes threads. This class represents the Thread object in System Monitor .
'  @Command For Counters - wmic path Win32_perfformatteddata_perfproc_thread         
'  @Counters -  ContextSwitchesPerSec   PercentProcessorTime   PercentUserTime    PercentPrivilegedTime    ElapsedTime    PriorityCurrent     PriorityBase    StartAddress& ThreadState    ThreadWaitReason    IDProcess     IDThread  

'  @GDF - cm_win_Thread_stats.gdf
'-----------------------------------------------------------------------------------------------------------------------

' Represent local computer
strComputer = "."
'WMI tasks object to obtain information about services, including dependent or antecedent services running on computer.
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")	
'The SWbemRefresher object is a container object that can refresh the data for all the objects that are added to
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
' Object to holds WMI reference class object
Set colItems = objRefresher.AddEnum(objWMIService, _
    "Win32_perfformatteddata_perfproc_thread").objectSet
Rem this object holds the thread class object to get thread id and command line argument values
objRefresher.Refresh
'In win2003 its giving blank line b'coz it calling null values.
Wscript.Sleep 500
objRefresher.Refresh
'Hold file system object
Set objFSO = CreateObject("Scripting.FileSystemObject")
rem CAV_MON_HOME is used to get the working directory of cmon.
CAV_MON_HOME = objFSO.GetParentFolderName(objFSO.GetParentFolderName(WScript.ScriptFullName))
'Holds default sample interval 10 sec
const DEFAULT_INTERVAL = 10000
'Holds default test-run number = "NA"
const DEFAULT_TRNUM = "NA"
'Holds monitor arguments
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
' This Dictionary Object will hold  threadID as key and commandLineArgumentValue for given serachPattern of a process
Set processIdCmdArgsMap = CreateObject("Scripting.Dictionary")
'constant to convert byte into MB
const ByteToMB = 1048576 
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


'Condition will check weather user specified name of comma seprated vector or not. 

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

Rem condition to check weather searchPattern is given in monnitor agruments or not
If colNamedArguments.Exists("searchPattern") Then
 searchPattern = colNamedArguments.Item("searchPattern")
Else
 searchPattern = "NA"
End If

If NOT (searchPattern = "NA") then
  generateProcessIdAndCommandArgsMap()
End If

Rem Generating map of the thread Id and thread Command Line Argument value for searcPattern 

Function generateProcessIdAndCommandArgsMap()
  Set processObjItem = objWMIService.ExecQuery( _
  "SELECT * FROM Win32_Process",,48)
  For Each processOBJ in processObjItem
    processID = processOBJ.Processid
    cmdLineArgs = processOBJ.Commandline
    commanLineValue = ""
    Rem to check command line argument for thread should not be null and blank
    if Not ( IsNull(cmdLineArgs) OR IsEmpty(cmdLineArgs) ) then
      Rem to check command line should contain search pattern
      if Not (instr(cmdLineArgs , searchPattern)) = 0  then
      Rem here parttion the commandline args string in such way substring will contain arguments after the search pattern
       subStringCmdArgs = Mid(cmdLineArgs, instr(1, cmdLineArgs , searchPattern) + Len(searchPattern) + 1 , Len(cmdLineArgs))
        Rem to check substring after search pattern should not be blank
        if Not (IsEmpty(subStringCmdArgs)) then
         Rem take first character of sub string
         charAtFirstPosition = Mid(subStringCmdArgs,1,1)
        Rem check first character is <"> or not
        If (charAtFirstPosition = chr(34)) Then
          Rem get value between double quotes and ignore rest of the substring
          commanLineValue = Mid(subStringCmdArgs, 2, instr(2, subStringCmdArgs , chr(34)) -2)
	  Rem map value into dictionary for a thread id
          processIdCmdArgsMap.Add processID, commanLineValue
        else
          Rem check substring contains no space
          if(instr(1, subStringCmdArgs , chr(32))) = 0 then
           Rem substring the value upto the length of the string
           commanLineValue = Mid(subStringCmdArgs, 1, len(subStringCmdArgs))
          else
           Rem substring the value upto the first space character
	   commanLineValue = Mid(subStringCmdArgs, 1, instr(1, subStringCmdArgs , chr(32)))
          end if
           Rem putting the value into map
           processIdCmdArgsMap.Add processID, commanLineValue
        End If
      End if
    End if
   End if
  Next		
End Function


'This function is used to check duplicate thread searcPattern
Function isDuplicateSearchPatternValues(argValue)
  isDuplicateSearchPatternValues = 0
  mapItem = processIdCmdArgsMap.Items
  For Each strItem in mapItem
	if (argValue = strItem ) then
	   isDuplicateSearchPatternValues = isDuplicateSearchPatternValues + 1
	End if
  Next
End Function

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
      processID = objItem.IDProcess
      if NOT (vectorName = "") then
        vectorName = Replace(vectorName, " ","_")
      Rem Adding vector prefix for all the thread name for which we had parsed command line argument
      IF (processIdCmdArgsMap.Exists(processID)) then
         vectorPrefix = processIdCmdArgsMap.Item(processID)
         duplicateCount = isDuplicateSearchPatternValues(vectorPrefix )
	 vectorPrefix =  Replace(vectorPrefix, "/", "")
	 vectorPrefix =  Replace(vectorPrefix, ":", "")
         vectorPrefix = Replace(vectorPrefix, " ", "")
         if (duplicateCount > 1) then
            vectorName = vectorName & "_" &  vectorPrefix
         else
           if( InStr(vectorName  , "#") > 0) then
             arrVectorWithHash = Split(vectorName,"#")
             vectorName = arrVectorWithHash (0)
           End if
           vectorName = vectorName & "_" &  vectorPrefix
         End if
      End if 	
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
       processID = objItem.IDProcess
       rem Adding vector prefix for all the thread name for which we had parsed command line argument
       IF (processIdCmdArgsMap.Exists(processID)) then
         vectorPrefix = processIdCmdArgsMap.Item(processID)
         duplicateCount = isDuplicateSearchPatternValues(vectorPrefix )
         vectorPrefix =  Replace(vectorPrefix, "/", "")
	 vectorPrefix =  Replace(vectorPrefix, ":", "")
         vectorPrefix = Replace(vectorPrefix, " ", "")
         if ( duplicateCount > 1) then
            vectorName = vectorName & "_" &  vectorPrefix
         else
           if( InStr(vectorName  , "#") > 0) then
             arrVectorWithHash = Split(vectorName,"#")
             vectorName = arrVectorWithHash (0)
           End if
           vectorName = vectorName & "_" &  vectorPrefix
         End if
       End if 
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
  If Not (strTrNum = DEFAULT_TRNUM) Then
    If Not objFSO.FileExists(runningTestFile) Then
      WScript.Quit [0]
    End If
  End If
  processIdCmdArgsMap.RemoveAll
  generateProcessIdAndCommandArgsMap()
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
    processID = objItem.IDProcess
    rem Adding vector prefix for all the thread name for which we had parsed command line argument
    IF (processIdCmdArgsMap.Exists(processID)) then
         vectorPrefix = processIdCmdArgsMap.Item(processID)
         duplicateCount = isDuplicateSearchPatternValues(vectorPrefix )
         vectorPrefix =  Replace(vectorPrefix, "/", "")
         vectorPrefix =  Replace(vectorPrefix, ":", "")
         vectorPrefix = Replace(vectorPrefix, " ", "")
         if ( duplicateCount > 1) then
            vectorName =  vectorName & "_" &  vectorPrefix
         else
           if( InStr(vectorName  , "#") > 0) then
             arrVectorWithHash = Split(vectorName,"#")
             vectorName = arrVectorWithHash (0)
           End if
           vectorName = vectorName & "_" &  vectorPrefix
         End if
    End if 
    Wscript.Echo getVectorID(vectorName) & ":" & vectorName & "|" & objItem.ContextSwitchesPerSec & " " & objItem.PercentProcessorTime & " " & objItem.PercentUserTime & " " & objItem.PercentPrivilegedTime & " " & objItem.ElapsedTime & " " & objItem.PriorityCurrent & " " & objItem.PriorityBase & " " & objItem.StartAddress& " " & objItem.ThreadState & " " & objItem.ThreadWaitReason & " " & objItem.IDProcess & " " & objItem.IDThread & vbCrlf
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
