@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name      :  kill_monitor.bat
REM Author    :  Prabhat Vashist
REM Purpose   :  To kill custom monitor on windows srever
REM Usage     :  kill_monitor [-n] (name of process)
REM Eg        :  kill_monitor -n CavMonCScript
REM Exit Values :
REM         0 - Success
REM         1 - Fails 
REM
REM Modification History :
REM     10/03/10 : Prabhat Vashist - Initial Version
REM
REM ---------------------------------------------------------------------------------

REM echo %2%

REM We were using copy of taskkill (CavMonTaskkill) but it did not work
REM One issue found in client(Redbox) i.e test run ends by ctr + z and Cavmon tries to kill all hang monitors but
REM after killing some monitors it getting stuck itself. We were not able to get exact problem but we found
REM one solution after adding 'start' keyword before taskkill.

start taskkill /IM %2 /F /T
if not errorlevel 0 (
    start taskkill /IM taskkill.exe /F /T
    exit -1;
  )
  
exit 0
REM pause
