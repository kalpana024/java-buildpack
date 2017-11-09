@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name    : cm_tcp_stats_count.bat
REM Author  : Prabhat Verma
REM Purpose : This is window copy of "cm_tcp_stats_count" for linux envrionment.
REM Usage   : cm_tcp_stats_count -i <Interval> -d <delay>
REM Output  : Established SynSent SynRcvd FinWait1 FinWait2 TimeWait Closed CloseWait LastAck Listening  Closing
REM           2 0 0 0 0 0 0 0 0 13 0
REM NETSTAT_FILE FORMAT -Windows
REM  TCP    127.0.0.1:49213        127.0.0.1:8080         TIME_WAIT
REM  TCP    192.168.1.99:139       0.0.0.0:0              LISTENING
REM  TCP    192.168.1.99:49168     192.168.1.70:22        ESTABLISHED
REM  TCP    192.168.1.99:49173     192.168.1.70:22        ESTABLISHED
REM Modification History :
REM 17/03/10 : Prabhat Verma- Initial Version
REM
REM ---------------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION
::This is set here hard coded need
::to pass dynamically  

for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"
set CAV_MON_HOME=%CAV_MON_HOME%
set ERROR_LOG_FILE=%CAV_MON_HOME%\logs\cm_tcp_states_count_error.log
::This is hard coded for run once need to pass dynamically
set MON_OPTION=1
set TEMP_DIR=%TEMP%
set ESTABLISHED=0
set SYN_SENT=0
set SYN_RECEIVED=0
set FIN_WAIT_1=0
set FIN_WAIT_2=0
set TIME_WAIT=0
set CLOSED=0
set CLOSE_WAIT=0
set LAST_ACK=0
set LISTENING=0
set CLOSING=0
set NETSTAT_FILE=%TEMP_DIR%\tcp_count.txt
set NETSTAT_CMD=netstat -an -p tcp
set FREQUENCY=%2
set DELAY=%4

set ARGS_COUNT=0
for %%A in (%*) do (
  set /a ARGS_COUNT=!ARGS_COUNT!+1
)

if "%ARGS_COUNT%" NEQ "0" (
  if "%ARGS_COUNT%" NEQ "2" (
    if "%ARGS_COUNT%" NEQ "4" (
      call :Usage
    )
  )
)


if %FREQUENCY%XX==XX (
  set FREQUENCY=10
)

if %DELAY%XX==XX (
  set DELAY=60
)

::call :sleep_for_time %DELAY%

::For every time
if "%MON_OPTION%" EQU "1" (

  call :get_count_for_netstat
  call :show_output
  exit 0
)

::For run once
if "%MON_OPTION%" EQU "2" (

:ENDLESSLOOP
  call :get_count_for_netstat
  call :show_output
  call :sleep_for_time %FREQUENCY%
 goto ENDLESSLOOP

)

exit 0

::----------------------------- Functions -------------------------

:show_output
  echo %ESTABLISHED% %SYN_SENT% %SYN_RECEIVED% %FIN_WAIT_1% %FIN_WAIT_2% %TIME_WAIT% %CLOSED% %CLOSE_WAIT% %LAST_ACK% %LISTENING% %CLOSING%
 goto:eof

::This will set all variables for tcp-socket stats
:get_count_for_netstat
  call cmd /c %NETSTAT_CMD% > %NETSTAT_FILE%

  IF not errorlevel 0 (
    call :error_log "Error in the execution of the command %NETSTAT_CMD%"
    del %NETSTAT_FILE%
    exit -1
  )
  
  if not exist %NETSTAT_FILE% (
                          call :error_log "Error in getting output of the command %NETSTAT_CMD%"
                          del %NETSTAT_FILE%
                          exit -1
  )
    
  call :reset_counter
  FOR /f "tokens=4 skip=2"  %%G IN (%NETSTAT_FILE%) DO (
    :: set all vars here
    if "%%G" EQU "ESTABLISHED" (
       set /a ESTABLISHED=!ESTABLISHED!+1
    )
    if "%%G" EQU "SYN_SENT" (
       set /a SYN_SENT=!SYN_SENT!+1
    )
    if "%%G" EQU "SYN_RECEIVED" (
       set /a SYN_RECEIVED=!SYN_RECEIVED!+1
    )
    if "%%G" EQU "FIN_WAIT_1" (
       set /a FIN_WAIT_1=!FIN_WAIT_1!+1
    )
    if "%%G" EQU "FIN_WAIT_2" (
       set /a FIN_WAIT_2=!FIN_WAIT_2!+1
    )
    if "%%G" EQU "TIME_WAIT" (
       set /a TIME_WAIT=!TIME_WAIT!+1
    )
    if "%%G" EQU "CLOSED" (
       set /a CLOSED=!CLOSED!+1
    )
    if "%%G" EQU "CLOSE_WAIT" (
       set /a CLOSE_WAIT=!CLOSE_WAIT!+1
    )
    if "%%G" EQU "LAST_ACK" (
       set /a LAST_ACK =!LAST_ACK!+1
    )
    if "%%G" EQU "LISTENING" (
       set /a LISTENING=!LISTENING!+1
    )
    if "%%G" EQU "CLOSING" (
       set /a CLOSING=!CLOSING!+1
    )
  )
 goto:eof

:Usage
  echo cm_tcp_states_count [ -i ^| -d ]
  exit -1
 goto:eof

:error_log
   echo Error: %~1
   
   set CUR_DATE=
   
   FOR /f  "delims=(=" %%G IN ('echo %date%') DO (
     set CUR_DATE=!CUR_DATE! %%G
   )
      
   set CUR_TIME=
   
   FOR /f  "delims=(=" %%G IN ('echo %time%') DO (
     set CUR_TIME=!CUR_TIME! %%G
   )
   echo !CUR_DATE! !CUR_TIME!^|%~1 >> %ERROR_LOG_FILE%
goto:eof


:sleep_for_time
  CHOICE /T %~1 /C ync /CS /D y>nul
 goto:eof
 
 :reset_counter
    set ESTABLISHED=0
    set SYN_SENT=0
    set SYN_SENT=0
    set SYN_RECEIVED=0
    set FIN_WAIT_1=0
    set FIN_WAIT_2=0
    set TIME_WAIT=0
    set CLOSED=0
    set CLOSE_WAIT=0
    set LAST_ACK=0
    set LISTENING=0
    set CLOSING=0
  goto:eof
   
  
ENDLOCAL
