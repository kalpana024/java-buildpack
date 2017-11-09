@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name      :  install.bat
REM Author    :  Prabhat Vashist
REM Purpose   :  To install Create Server on Windows Server as service.
REM
REM Modification History :
REM     05/07/10 : Prabhat Vashist - Initial Version
REM
REM ---------------------------------------------------------------------------------

for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"
set LOG_FILE="%CAV_MON_HOME%\cmon_installation_debug.log"
set CAV_MON_HOME=%CAV_MON_HOME%
set JSL_EXE=CavMonAgent.exe

REM Before install, first need to stop CavMonAgent and delete as service
C:\\Windows\\System32\\sc stop CavMonAgent >> %LOG_FILE%
if %ERRORLEVEL% NEQ 0 (
    echo Error in Stoping CavMonAgent >> %LOG_FILE%
  ) else (
    echo CavMonAgent Stopped Succesfully >> %LOG_FILE%
	)
Rem Sleep for 2 sec, waiting for stopping CavMonAgent
C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul

echo Removing CavMonAgent... >> %LOG_FILE%
REM used to delete the service  
C:\\Windows\\System32\\sc delete CavMonAgent >> %LOG_FILE%
Rem Sleep for 2 sec, waiting for deleting CavMonAgent
C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
 if %ERRORLEVEL% NEQ 0 (
    echo Service Disabled or not installed. >> %LOG_FILE%
    ) else (
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
REM del %LOG_FILE%

echo "=========================================================" >> %LOG_FILE%
echo "\nInstallation Started\n" >> %LOG_FILE%
echo "\n\nRefer cavisson\monitors\cmon_installation_debug.log for additional details\n\n" >> %LOG_FILE%

echo "Creating Directory Structure\n" >> %LOG_FILE% 
mkdir "%CAV_MON_HOME%"\\logs >> %LOG_FILE%
mkdir "%CAV_MON_HOME%"\\sys  >> %LOG_FILE%


echo "Coping configuration files in Directory Structure\n" >> %LOG_FILE%

copy "%CAV_MON_HOME%"\\thirdparty\\*.ini  "%CAV_MON_HOME%"\\sys\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping *.ini files in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )


copy "%CAV_MON_HOME%"\\thirdparty\\*.exe  "%CAV_MON_HOME%"\\sys\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping *.exe files in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "Coping cscript.exe in Directory Structure\n" >> %LOG_FILE% 

copy C:\\Windows\\System32\\cscript.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping cscript.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "cscript.exe copied in Directory Structure\n" >> %LOG_FILE% 


echo "Rename cscript.exe to CavMonCScript.exe in Directory Structure\n" >> %LOG_FILE% 

rename "%CAV_MON_HOME%"\\bin\\cscript.exe CavMonCScript.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename cscript.exe to CavMonCScript.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )


echo "Installing CavMonAgent\n" >> %LOG_FILE%

echo "Coping cmd.exe in Directory Structure\n" >> %LOG_FILE%

copy C:\\Windows\\System32\\cmd.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping cmd.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )


echo "cmd.exe copied in Directory Structure\n" >> %LOG_FILE%

echo "Rename cmd.exe to CavMonCmd.exe in Directory Structure\n" >> %LOG_FILE%

rename "%CAV_MON_HOME%"\\bin\\cmd.exe CavMonCmd.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename cscript.exe to CavMonCScript.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "Installing CavMonCmd.exe\n" >> %LOG_FILE%


echo "Coping taskkill.exe in Directory Structure\n" >> %LOG_FILE%

copy C:\\Windows\\System32\\taskkill.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping taskkill.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "taskkill.exe copied in Directory Structure\n" >> %LOG_FILE%

echo "Rename taskkill.exe to CavMonTaskkill.exe in Directory Structure\n" >> %LOG_FILE%

rename "%CAV_MON_HOME%"\\bin\\taskkill.exe CavMonTaskkill.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename taskkill.exe to CavMonTaskkill.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "Installing CavMonTaskkill.exe\n" >> %LOG_FILE%

"%CAV_MON_HOME%"\\sys\\%JSL_EXE% -install  >> %LOG_FILE%
if not errorlevel 0 (
    echo "Installation Fails -- Cannot Install CavMonAgent\n" >> %LOG_FILE%
    exit -1;
  )

echo "Installation of CavMonAgent Complete\n" >> %LOG_FILE%

echo "Start CavMonAgent\n" >> %LOG_FILE%

C:\\Windows\\System32\\net start CavMonAgent >> %LOG_FILE%
if not errorlevel 0 (
    echo "Service not Started on this computer\n" >> %LOG_FILE%
    exit -1;
  )

echo "Service Started on this computer\n" >> %LOG_FILE%
echo "\n=========================================================\n" >> %LOG_FILE%

REM pause
exit 0
