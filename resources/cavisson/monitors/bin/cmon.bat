@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name    : cmon.bat
REM Author  : Prabhat Vashist
REM Purpose : This is to install/upgrade/start/stop/restart/show-version of Create Server on windows agent
REM Note    : Make sure that this batch file is executed with administrator privilege. 
REM
REM Modification History :
REM 07/15/10 : Prabhat Vashist- Initial Version
REM
REM ---------------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

REM Need to set java
REM set JAVA_HOME=C:\Apps\jdk1.5.0_01
set JAVA_BIN="%JAVA_HOME%\bin\java"

REM Need to set CAV_MON_HOME path
set CAV_MON_HOME=""

REM Need to set JSL_NAME based on OS type (32 bit/64 bit)
REM set JSL_NAME=CavMonAgent.exe

IF EXIST C:\\opt\\cavisson\\monitors (
   set CAV_MON_HOME=C:/opt/cavisson/monitors
   ) else (
   set userDir=%HOMEDRIVE%%HOMEPATH%
   echo %userDir%
   IF EXIST %userDir%/cavisson/monitors (
        set CAV_MON_HOME=%userDir%/cavisson/monitors
        ) else (
        echo cmon package may not be installed.
        exit -1
      )
   )

set CLASSPATH=%CAV_MON_HOME%/lib/java-getopt-1.0.9.jar;%CAV_MON_HOME%/custom;%CAV_MON_HOME%/bin;%CAV_MON_HOME%/bin/CavMonAgent.jar;%CAV_MON_HOME%/lib/CmonLib.jar;%CAV_MON_HOME%/lib/gcviewer-1.29.jar;%CAV_MON_HOME%/../netdiagnostics/thirdparty/lib/asm-all-4.0.jar;%CAV_MON_HOME%/../lib/base64.jar

%JAVA_BIN% -DCAV_MON_HOME=%CAV_MON_HOME% -DCLASSPATH=%CLASSPATH% InstallCmon %*

exit 0
