@ECHO off
REM --------------------------------------------------------------------
REM  Name: chm_get_server_logs.bat 
REM  Purpose: To ftp file or directory 
REM  Author:abhishek sharan
REM
REM
REM  How to use in mprof
REM  CHECK_MONITOR STG-RBApp01 RB01 90 NA 2 NA NA NA c:/opt/cavisson/monitors/bin/chm_get_server_logs.bat -dir "C:\Redbox\logs" -dest KioskRB01Logs
REM  CHECK_MONITOR STG-RBApp02 RB02 90 NA 2 NA NA NA c:/opt/cavisson/monitors/bin/chm_get_server_logs.bat -dir "C:\Redbox\logs" -dest KioskRB02Logs
REM  CHECK_MONITOR STG-RBApp03 RB03 90 NA 2 NA NA NA c:/opt/cavisson/monitors/bin/chm_get_server_logs.bat -dir "C:\Redbox\logs" -dest KioskRB03Logs
REM  CHECK_MONITOR STG-RBApp04 RB04 90 NA 2 NA NA NA c:/opt/cavisson/monitors/bin/chm_get_server_logs.bat -dir "C:\Redbox\logs" -dest KioskRB04Logs
REM --------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION


for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"
set CAV_MON_HOME=%CAV_MON_HOME%
REM Set CAV_MON_HOME=E:\\chm_get_server_logs
Set ZIP_CMD_NAME=%CAV_MON_HOME%\bin\7z
REM Set ZIP_CMD_NAME=E:\chm_get_server_logs\7z


Set FLAG_ARGS=%1
Set FLAG_ARGS_FTP=%3
Set DIR_TO_TAR=%~f2
Set DIR_NAME=%~n2
Set FILE_SIZE=0
Set FILE_NAME=%4
Set TAR_FILE_NAME=%FILE_NAME%.tar
Set GZIP_FILE=%TAR_FILE_NAME%.gz
Set ERROR_LOG_FILE=%CAV_MON_HOME%\logs\chm_get_server_logs_%FILE_NAME%_error.log
REM Set ERROR_LOG_FILE=%CAV_MON_HOME%\logs\chm_get_server_logs_error.log
REM Set ERROR_LOG_FILE=%CAV_MON_HOME%\logs\%MON_TEST_RUN%_error.log

REM Set DEBUG_LOG_FILE=%CAV_MON_HOME%\logs\chm_get_server_logs_%FILE_NAME%_debug.log

REM Set DEBUG_LOG_FILE=%CAV_MON_HOME%\logs\%MON_TEST_RUN%_debug.log
Set DEBUG_LOG_FILE=nul

Set yac=0

Set TEMP_DIR=%TEMP%
if "%TEMP_DIR%" == "" ( Set TEMP_DIR=C:\\WINDOWS\\Temp )

call :countarg %*

if "%yac%" == "0" call :Usage

date /t >>%DEBUG_LOG_FILE%
time /t >>%DEBUG_LOG_FILE%
 
if "%FLAG_ARGS%"=="-dir" (
   If "%FLAG_ARGS_FTP%"=="-dest" (
   REM Check if dir exists or not
   if not exist "%DIR_TO_TAR%" ( echo Error: specified  directory not found 
                                call :ShowError )

   if "%FILE_NAME%" == "" ( echo Error: :Destination not specified 
                                call :ShowError )
        call :make_tar_of_folder 
    ) else (
        call :Usage
    )
) else if "%FLAG_ARGS%"=="-file" (
   If "%FLAG_ARGS_FTP%"=="-dest" (
   REM Check if file exists or not
   if not exist "%DIR_TO_TAR%" ( echo Error: specified file not found 
                           call :ShowError )
			   
   if "%FILE_NAME%" == "" ( echo Error: Destination not specified 
                                call :ShowError )
        call :make_tar_of_file 
    ) else (
        call :Usage
    )
) else (
        call :Usage
)

call :del_tmp_dir_files
REM cd >>%DEBUG_LOG_FILE%
 
if exist %GZIP_FILE% ( 
  echo In if condition  >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
  call :fileftp
  REM pause
  call :del_gzip_file
  call :ns_check_mon_pass_and_exit
) else (
  Echo Error: Compressed tar file created is not existing. File name =  %GZIP_FILE% >>%ERROR_LOG_FILE%
  Echo Error: Compressed tar file created is not existing. File name =  %GZIP_FILE%
  REM pause  
  call :del_tmp_dir_file
  call :ns_check_mon_fail_and_exit
)

REM pause
exit 0
 
 
 
:: ------------------------------- functions -------------------------------------

:del_gzip_file
  del /f /q "%TEMP_DIR%\%GZIP_FILE%" >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
  IF %ERRORLEVEL% NEQ 0 (
  echo  %GZIP_FILE% not deleted >>%DEBUG_LOG_FILE%
  )
  REM goto ShowError
  goto :eof

:del_tmp_dir_files
  del /f /q "%TEMP_DIR%\%TAR_FILE_NAME%" >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
  IF %ERRORLEVEL% NEQ 0 (
  echo  %TAR_FILE_NAME% not deleted >>%DEBUG_LOG_FILE%
  )

  if exist "%fileName%" (
  del /f /q "%fileName%" >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE% 
  )
  IF %ERRORLEVEL% NEQ 0 (
  echo  %fileName% not deleted >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE% 
  )
  REM for dir, we need delete dir 
  if exist "%TEMP_DIR%\%DIR_NAME%-tar" ( 
  del /f /s /q "%TEMP_DIR%\%DIR_NAME%-tar" >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
  rd /s /q "%TEMP_DIR%\%DIR_NAME%-tar" >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
  ) else (
  echo ***************No Directory to delete******************* >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
  ) 
  goto :eof

:fileftp 
    echo In fileftp  >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   REM Need to debug why we need to do if exists two times. It does not work without this 
   if exist %GZIP_FILE% (
   if exist %GZIP_FILE% (
    FOR %%R IN (%GZIP_FILE%) DO (
      set FILE_SIZE=%%~zR
      
       )
     )
   )
   echo FTPFile:%GZIP_FILE%:!FILE_SIZE!
    type %GZIP_FILE%  2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError
   
   goto :eof
   

:make_tar_of_folder
   echo In  make folder and exit >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   cd %TEMP_DIR%  >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   md "%TEMP_DIR%\%DIR_NAME%-tar" >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   xcopy /s /e /i /y /h /c "%DIR_TO_TAR%" "%DIR_NAME%-tar" >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
  
   %ZIP_CMD_NAME% a -ttar %TAR_FILE_NAME% "%DIR_NAME%-tar" -r >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError 

   %ZIP_CMD_NAME% a -tgzip %GZIP_FILE% %TAR_FILE_NAME% >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError

   REM copy %GZIP_FILE% new.tar.gz >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   goto :eof

:make_tar_of_file
  echo In  make_tar_of_file >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   xcopy /c "%DIR_TO_TAR%" "%TEMP_DIR%" >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError
   
   For %%A in ("%DIR_TO_TAR%") do (
    Set fileName=%%~nxA
   )
   echo File name is: %fileName% >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   cd %TEMP_DIR%  >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   set FILE_TO_TAR=%DIR_TO_TAR%
   echo %TEMP_DIR% %FILE_TO_TAR% >>%DEBUG_LOG_FILE%
   %ZIP_CMD_NAME% a -ttar %TAR_FILE_NAME% "%fileName%" -ssw >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError 

   %ZIP_CMD_NAME% a -tgzip %GZIP_FILE% %TAR_FILE_NAME%  >>%DEBUG_LOG_FILE%  2>>%ERROR_LOG_FILE%
   IF %ERRORLEVEL% NEQ 0 goto ShowError
   REM pause
   goto :eof 



:ns_check_mon_pass_and_exit
   echo In  chk mon pass and exit >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   echo CheckMonitorStatus:Pass
   exit 0
   goto :eof

:ns_check_mon_fail_and_exit
   echo In  chk mon fail and exit >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   echo CheckMonitorStatus:Fail
   exit -1
   goto :eof

:countarg
  set yca=%1
  if defined yca set /a yac+=1&shift&goto countarg
  goto :eof

:Usage
   echo In  Usage >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   Echo chm_get_server_logs.bat -dir  [full-path] -dest [file-name]
   Echo chm_get_server_logs.bat -file [full-path with file name] -dest [file-name]
   call :ns_check_mon_fail_and_exit
   goto :eof

:ShowError
   echo In  ShowError >>%DEBUG_LOG_FILE% 2>>%ERROR_LOG_FILE%
   REM delete any files created 
   call :del_tmp_dir_files
   call :del_gzip_file
   call :ns_check_mon_fail_and_exit
   goto :eof

ENDLOCAL
