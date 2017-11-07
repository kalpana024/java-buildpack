@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name      :  uninstall.bat
REM Author    :  Prabhat Vashist
REM Purpose   :  To remove CavMonAgent from Windows Server as service.
REM
REM Modification History :
REM     07/22/10 : Prabhat Vashist - Initial Version
REM
REM ---------------------------------------------------------------------------------

for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"

set CAV_MON_HOME=%CAV_MON_HOME%
set LOG_FILE="%CAV_MON_HOME%"\\cmon_uninstall.log


REM del %LOG_FILE%

echo "=========================================================" >> %LOG_FILE%
echo Uninstallation Started >> %LOG_FILE%
echo Uninstalling CavMonAgent ....
echo Stoping CavMonAgent >> %LOG_FILE%

REM used to stop the service
C:\\Windows\\System32\\sc stop CavMonAgent >> %LOG_FILE%

if %ERRORLEVEL% NEQ 0 (
    echo Error in Stoping CavMonAgent >> %LOG_FILE%
  ) else (
    echo CavMonAgent Stopped Succesfully >> %LOG_FILE%
	)

echo Removing CavMonAgent... >> %LOG_FILE%
C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
REM used to delete the service  
C:\\Windows\\System32\\sc delete CavMonAgent >> %LOG_FILE%

  if %ERRORLEVEL% NEQ 0 (
    echo Service Disabled, Unable to remove installation directory. >> %LOG_FILE%
    ) else (
	    Rem Sleep for 2 sec, waiting for stopping CavMonAgent
            C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
		del "%CAV_MON_HOME%"\\bin\\CavMonCScript.exe
		del "%CAV_MON_HOME%"\\bin\\CavMonCmd.exe
		del "%CAV_MON_HOME%"\\bin\\del CavMonTaskkill.exe
	    rmdir "%CAV_MON_HOME%"\\logs /s /q
            del "%CAV_MON_HOME%"\\sys\\CavMonAgent.exe
            del "%CAV_MON_HOME%"\\sys\\CavMonAgent.ini
            del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.exe
            del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.ini
        if %ERRORLEVEL% NEQ 0 (
           echo Got Error to remove installation directory.
	     ) else (
            echo CavMonAgent Removed Succesfully. >> %LOG_FILE%
	   )
	)

echo Uninstallation of CavMonAgent is Completed. >> %LOG_FILE%
echo Service Removed from this computer. >> %LOG_FILE%
echo "=========================================================" >> %LOG_FILE%

exit 0
