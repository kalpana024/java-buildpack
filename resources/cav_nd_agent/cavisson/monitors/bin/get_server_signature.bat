@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name : get_server_signature.bat
REM Author : Atul Kumar
REM Purpose : This is window copy of "get_server_signature" for linux envrionment.
REM Usage   :  get_server_signature <Signature name> {-f <file name> | -c <command with/without args>}
REM
REM Where:
REM       -f use for 'File Name' if server signature type is 'File'
REM       -c use for 'Command Name' if server signature type is 'Command'
REM
REM Example - If Server signature type is 'Command':
REM  SERVER_SIGNATURE  192.168.18.106  Server_sig_version Command  <command_to_run>
REM  Output of command '<command_to_run>' would be ftp in test run log directory as TRXXXX/server_signatures/Server_sig_version.ssf
REM
REM Example - If Server signature type is 'File':
REM  SERVER_SIGNATURE  192.168.1.53  File  Server_sig_process   File  c:/home/process_status.log
REM  Output of File '/tmp/process_status.log' would be ftp in test run log directory as TRXXXX/server_signatures/Server_sig_process.ssf
REM
REM Modification History :
REM 12/03/10 : Atul Kumar - Initial Version
REM 14/07/11 : Manish Kumar Mishra - Support spacec in double quote 
REM ---------------------------------------------------------------------------------


SETLOCAL ENABLEDELAYEDEXPANSION
set TEMP_DIR=%TEMP%
rem set TEMP_DIR=C:\opt\cavisson\monitors\tmp
set SIGNATURE=%1
set SIGNATURE_FILE=%SIGNATURE%.ssf
set FLAG_ARGS=%2
set COMMAND=%3
set PROCESS_FILE=%TEMP_DIR%\server_signature.txt
set FILE_SIZE=0


if '%FLAG_ARGS%'=='-c' (
  ::Loop to get command and all its args
  FOR %%A IN ( %* ) DO (
    if "%%A" NEQ "%SIGNATURE%" (
      if "%%A" NEQ "%FLAG_ARGS%" (
        if "%%A" NEQ "%COMMAND%" (           
  	  set COMMAND=!COMMAND! %%A
          )
        )
      )
   )
   rem we check again because if it try to give a file name which is store in a directory eg: C:\Dir Name\file.txt
   rem then this bat file behave very strangly.
   if '%FLAG_ARGS%'=='-c' (
     call :run_cmd
   )
 ) else ( 

   if '%FLAG_ARGS%'=='-f' (
     set PROCESS_FILE=%3
   ) else (
     call :display_help_and_exit 
   )
 )         
 
 if exist %PROCESS_FILE% (
   if exist %PROCESS_FILE% (
    FOR %%R IN (%PROCESS_FILE%) DO (
      set FILE_SIZE=%%~zR
    )
 )
   echo FTPFile:%SIGNATURE_FILE%:!FILE_SIZE!
   type %PROCESS_FILE%
   if %FLAG_ARGS%==-c (
     del %PROCESS_FILE%
     )
   call :ns_check_mon_pass_and_exit
) else (
   call :ns_log_event "Major" "File '%PROCESS_FILE%' does not exist for FTP."
   call :ns_check_mon_fail_and_exit
)
 
 
 
 :: ------------------------------- functions -------------------------------------
 
::run_cmd function 
:run_cmd
  call %COMMAND% > %PROCESS_FILE% 
  IF not errorlevel 0 (
                        call :ns_log_event "Major","Error in running command '%COMMAND%' for getting server signature '%SIGNATURE%'"
	                del %PROCESS_FILE% 
                        call :ns_check_mon_fail_and_exit
  ) 
 goto:eof
  
 :ns_log_event
   set VERSION=1.0
   set SEVERITY=%~1
   set EVENT_MSG=%~2
   echo Event:%VERSION%:%SEVERITY%^|%EVENT_MSG%
  goto:eof
  
 :ns_check_mon_fail_and_exit
    exit -2
  goto :eof
  
  :ns_check_mon_pass_and_exit
     echo CheckMonitorStatus:Pass
     exit 0
   goto:eof 
  
  :display_help_and_exit
    echo "Usage: get_server_signature <Signature name> {-f <file name> | -c command}"
    exit -1
  goto:eof
 
 ENDLOCAL
