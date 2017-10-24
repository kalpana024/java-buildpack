##############################################################################################
# Name    : ns_check_monitor_func.sh
# Author  : Archana
# Purpose : Utility functions for check monitors
# Note:
#   If ftp daemon is not start then to start ftp service use: (Required only if ftp is done using ftp command)
#   /etc/init.d/vsftpd restart
# Known Issue: 
#   Exported variables not available on remote machine
# Initial version  :  April 01 2009
# Modified version :  November 05 2009  - support ftp with absolute path
#                     September 11 2012 - Replaced = with = everywhere because = in not working in SunOS.
#                                         Replaced exit -1 with exit 255 because exit -1 is not working in SunOS. 
#                     October 31 2012   - Support for HPUX.
##############################################################################################

#exported variables list
ns_check_monitor_log_exported_variables()
{
  echo "VECTOR_NAME = $VECTOR_NAME"
  echo "MON_NS_WDIR = $MON_NS_WDIR"
  echo "CAV_MON_HOME = $CAV_MON_HOME"
  echo "MON_CAVMON_SERVER_NAME = $MON_CAVMON_SERVER_NAME"
  echo "MON_NS_SERVER_NAME = $MON_NS_SERVER_NAME"
  echo "MON_TEST_RUN = $MON_TEST_RUN"
  echo "MON_PARTITION_IDX = $MON_PARTITION_IDX"
  echo "MON_CHECK_START_DELAY = $MON_CHECK_START_DELAY"
  echo "MON_START_EVENT = $MON_START_EVENT"
  echo "MON_OPTION = $MON_OPTION"
  echo "MON_FREQUENCY = $MON_FREQUENCY"
  echo "MON_CHECK_COUNT = $MON_CHECK_COUNT"
  echo "MON_PGM_NAME = $MON_PGM_NAME"
  echo "MON_PGM_ARGS = $MON_PGM_ARGS"
  echo "MON_TIMEOUT = $MON_TIMEOUT"
  echo "MON_ACCESS = $MON_ACCESS"
  echo "MON_REMOTE_IP = $MON_REMOTE_IP"
  echo "MON_REMOTE_USER_NAME = $MON_REMOTE_USER_NAME"
  echo "MON_REMOTE_PASSWD = $MON_REMOTE_PASSWD"
  echo "MON_NS_FTP_USER = $MON_NS_FTP_USER"
  echo "MON_NS_FTP_PASSWORD = $MON_NS_FTP_PASSWORD"
  echo "CAV_MON_TMP_DIR = $CAV_MON_TMP_DIR"
  echo "UNIX_SHELL = $UNIX_SHELL"
  echo "MON_VECTOR_SEPARATOR = $MON_VECTOR_SEPARATOR"
}

##########################################################

NS=$MON_NS_SERVER_NAME
NS_USER=$MON_NS_FTP_USER
NS_PASSWORD=$MON_NS_FTP_PASSWORD
LOG_DIR=$MON_NS_WDIR/logs/
SERVER_DIR=server_logs
SERVER_NAME=`uname -n`

MAX_UNSIGNED_LONG_32=4294967295
MAX_UNSIGNED_LONG_64=18446744073709500000
PREV_MON_FILE_SIZE=0

#Setting awk command for sun os
OS_NAME=`uname`
if [ "$OS_NAME" = "SunOS" ]; then
  AWK_CMD="nawk"
else
  AWK_CMD="awk"
fi
export AWK_CMD

# Manish: Just include this library and use Library macro for differnt commad
# For Eg: for ps command use LIB_PS_CMD_FOR_DATA 
LIB_OS_NAME=`uname`

lib_set_sun_cmd()
{
  LIB_PS_CMD_FOR_DATA="/usr/bin/ps"
  if [ ! -f /usr/ucb/ps ];then
    echo "Error: ps command not found on path /usr/ucb/ps. Hence standard ps command will be used."
    LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
  else
    LIB_PS_CMD_FOR_SEARCH="/usr/ucb/ps -auxwww"
  fi
  if [ ! -f /usr/xpg4/bin/grep ];then
    echo "Error: grep command not found on path /usr/xpg4/bin/grep. Hence extended regular expression may not be supported."
    LIB_PS_GREP_CMD="/usr/bin/egrep -e"  #Search for a pattern_list(full regular expression that 
                                     #begins with a -).
 else
   LIB_PS_GREP_CMD="/usr/xpg4/bin/grep -E"
 fi
 LIB_AWK="nawk" #In SUN OS awk not support -v option
}

lib_set_linux_cmd()
{
  LIB_PS_CMD_FOR_DATA="ps"
  LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
  #PS_GREP_CMD="grep -e"
  LIB_PS_GREP_CMD="grep -E"      # Fixed bug: 4574
  LIB_AWK="awk"
}

lib_export_cmd()
{
  export IB_PS_CMD_FOR_DATA
  export LIB_PS_CMD_FOR_SEARCH
  export LIB_PS_GREP_CMD
  export LIB_AWK
}

lib_set_cmd()
{
  if [ "X$LIB_OS_NAME" = "XSunOS" ]; then
    lib_set_sun_cmd
  else #Linux,AIX
    lib_set_linux_cmd
  fi

  lib_export_cmd 
}

lib_run_command_with_wait()
{
  LOC_RUN_CMD=$1
  LOC_CMD_OUT_FILE=$2
  LOC_WAIT_TIME=$3
  LOC_CHECK_TIME=$4

  debug_log "Running command $LOC_RUN_CMD. Output file = $LOC_CMD_OUT_FILE, Wait Time = $LOC_WAIT_TIME, Check Time = $LOC_CHECK_TIME"
  
  eval nohup $LOC_RUN_CMD 1>$LOC_CMD_OUT_FILE 2>&1 &
 
  #Save exit status
  EXIT_STATUS=$?
      
  #Get pid of the command
  CMD_PID=$!
            
  #Note - nohup exit status is baed on whether is was able to run the command or not. Command exit status is not returned
  if [ $EXIT_STATUS != 0 ]; then
    error_log_and_console "Error in running command $LOC_RUN_CMD. Exit status = $EXIT_STATUS"
    cat $LOC_CMD_OUT_FILE
    rm -f $LOC_CMD_OUT_FILE
    exit $EXIT_STATUS
  fi
                                                              
  LOC_TOTAL_TIME=0
  debug_log "Command started OK. Going to wait for the command to complete with wait time of $LOC_WAIT_TIME seconds"

  while [ $LOC_TOTAL_TIME -lt $LOC_WAIT_TIME ];
  do
    ps -p $CMD_PID >/dev/null 2>&1
    if [ $? != 0 ]; then
    # Wait is used to get the exit status of the command as nohup does not give this
      wait $CMD_PID
      EXIT_STATUS=$?
      if [ $EXIT_STATUS != 0 ]; then
        error_log_and_console "Error in running command $LOC_RUN_CMD. Exit status = $EXIT_STATUS"
        cat $LOC_CMD_OUT_FILE
        rm -f $LOC_CMD_OUT_FILE
        exit $EXIT_STATUS
      fi
      debug_log "Command is over with success status"
      break
     fi
     LOC_TOTAL_TIME=`expr $LOC_TOTAL_TIME + 1`
     debug_log "Command is still running with PID $CMD_PID. Sleeping for $LOC_CHECK_TIME seconds. Total wait time so far is $LOC_TOTAL_TIME"
     sleep $LOC_CHECK_TIME
   done

   if [ $LOC_TOTAL_TIME -ge $LOC_WAIT_TIME ]; then
        #Killing hanging command
      kill -9 $CMD_PID
      error_log_and_console_exit "Error in getting output of command in maximum wait time of $LOC_WAIT_TIME seconds"
   fi
   debug_log "Total time taken by command to execute = $LOC_TOTAL_TIME seconds."
} 

lib_run_command_for_heap_tcp_with_wait()
{
  tcp_flag=0
  LOC_RUN_CMD=$1
  LOC_RUN_CMD_FORCEFULLY=$2
  LOC_CMD_OUT_FILE=$3
  LOC_WAIT_TIME=$4
  LOC_CHECK_TIME=$5

  debug_log "Running command $LOC_RUN_CMD. Output file = $LOC_CMD_OUT_FILE, Wait Time = $LOC_WAIT_TIME, Check Time = $LOC_CHECK_TIME, LOC_RUN_CMD_FORCEFULLY = $LOC_RUN_CMD_FORCEFULLY"

  echo $LOC_RUN_CMD |grep "tcpdump" >/dev/null
  if [ $? -eq 0 ]; then
    tcp_flag=1
    trace_log "Going to run '$LOC_RUN_CMD' command"
    eval nohup $LOC_RUN_CMD 2>/dev/null 1>&2 &
  else   #For heap dump
    eval nohup $LOC_RUN_CMD 1>>$LOC_CMD_OUT_FILE 2>/dev/null &
  fi

  #Save exit status
  EXIT_STATUS=$?
  #Get pid of the command
  CMD_PID=$!
  #sleep 1
  #cat $LOC_CMD_OUT_FILE
  #Note - nohup exit status is based on whether is was able to run the command or not. Command exit status is not returned
  if [ $EXIT_STATUS != 0 ]; then
      error_log_and_console "Error in running command $LOC_RUN_CMD. Exit status = $EXIT_STATUS"
      cat $LOC_CMD_OUT_FILE
      rm -f $LOC_CMD_OUT_FILE
    exit $EXIT_STATUS
  fi

  LOC_TOTAL_TIME=0
  debug_log "Command started OK. Going to wait for the command to complete with wait time of $LOC_WAIT_TIME seconds"

  while [ $LOC_TOTAL_TIME -lt $LOC_WAIT_TIME ];
  do
    ps -p $CMD_PID >/dev/null 2>&1
    if [ $? != 0 ]; then
      #Wait is used to get the exit status of the command as nohup does not give this
      wait $CMD_PID
      EXIT_STATUS=$?
      if [ $EXIT_STATUS != 0 ]; then
        if [ $FORCE_FLAG -eq 1 ]; then
          error_log_and_console "Error in running command $LOC_RUN_CMD_FORCEFULLY. Exit status = $EXIT_STATUS"
          cat $LOC_CMD_OUT_FILE
          rm -f $LOC_CMD_OUT_FILE
          exit $EXIT_STATUS
        fi

        if [ $tcp_flag -eq 1 ]; then
          trace_log "Running tcpdump forcefully. Command is $LOC_RUN_CMD_FORCEFULLY"
          eval nohup $LOC_RUN_CMD_FORCEFULLY 2>/dev/null 1>&2 &
        else
          #echo "Taking heap dump forcefully using command: $LOC_RUN_CMD_FORCEFULLY"
          debug_log "Running jmap forcefully. Command is $LOC_RUN_CMD_FORCEFULLY"
          eval nohup $LOC_RUN_CMD_FORCEFULLY 1>>$LOC_CMD_OUT_FILE 2>/dev/null  &
        fi

        #Save exit status
        EXIT_STATUS=$?
        #Get pid of the command
        CMD_PID=$!
        if [ $EXIT_STATUS != 0 ]; then
          error_log_and_console "Error in running command $LOC_RUN_CMD_FORCEFULLY. Exit status = $EXIT_STATUS"
          cat $LOC_CMD_OUT_FILE
          rm -f $LOC_CMD_OUT_FILE
          exit $EXIT_STATUS
        else
          FORCE_FLAG=1
          LOC_TOTAL_TIME=0
          continue
        fi
      fi

      debug_log "Command is over with success status"
      cat $LOC_CMD_OUT_FILE
      rm -f $LOC_CMD_OUT_FILE
      break
    fi
    LOC_TOTAL_TIME=`expr $LOC_TOTAL_TIME + $LOC_CHECK_TIME`
    debug_log "Command is still running with PID $CMD_PID. Sleeping for $LOC_CHECK_TIME seconds. Total wait time so far is $LOC_TOTAL_TIME"
    sleep $LOC_CHECK_TIME
  done

  if [ $LOC_TOTAL_TIME -ge $LOC_WAIT_TIME ]; then
    #Killing hanging command
    if [ $tcp_flag -eq 1 ]; then
      pkill -9 -P $CMD_PID
      trace_log "Wait time is over. Hence tcpdump command stopped."
      cat $LOC_CMD_OUT_FILE
    else
      kill -9 $CMD_PID
      error_log_and_console_exit "Error in getting output of command in maximum wait time of $LOC_WAIT_TIME seconds"
    fi
    rm -f $LOC_CMD_OUT_FILE
  fi

  debug_log "Total time taken by command to execute = $LOC_TOTAL_TIME seconds."
}


lib_set_cmd

#Flag to check if bc available or not
BC_AVAILABLE=1
check_bc_available()
{
  type -P bc 1>/dev/null 2>&1
  if [ $? -ne 0 ]; then
    BC_AVAILABLE=0
  fi
}

check_bc_available

#This method is to ftp file from where pre test check is running to netstorm machine
#ns_ptc_ftp_files <Source file name> <Destination file name>
#Where:
#   Source file name can be relative path or absolute path
#   Destination file name can not be absolute path
#Once FTPFile will use by check monitor then this method will not longer used
ns_ptc_ftp_files()
{
  FILE_NAME=$1
  LOG_FILE_NAME=$2
  testrun=$MON_TEST_RUN
  TEMP_LOG_FILE=/tmp/Check_monitor_log.$$
  #echo Test run number is $testrun from $NS
  ftp -vin $NS >>$TEMP_LOG_FILE <<+
user $NS_USER $NS_PASSWORD
cd $LOG_DIR/TR$testrun
pwd
mkdir $SERVER_DIR
cd $SERVER_DIR
mkdir $SERVER_NAME
cd $SERVER_NAME
put $FILE_NAME $LOG_FILE_NAME
bye
+
  rm -f $TEMP_LOG_FILE 
}

##########################################################

ns_log_event()
{
  VERSION="1.0"
  SEVERITY="$1"
  EVENT_MSG="$2"

  echo "Event:$VERSION:$SEVERITY|$EVENT_MSG"
}

#This method is to ftp file from where check monitor is running to netstorm machine
#ns_ftp_file <Source file name> [<Relative file path>]
#FTP file can be with or without relative path/absolute path
#FTP file will save in "TRXXX/server_logs/<server_name>/<Monitor name>/<file_name with relative path>"
# Example of with relative path:
#   ns_ftp_file /tmp/ps.log Process_Status
#   This file will ftp as "TRXXX/server_logs/<server_name>/<Monitor name>/Process_Status/ps.log"
# Example of with absolute path:
#   ns_ftp_file /tmp/ps.log /tmp/Process_Status
#   This file will ftp as "/tmp/Process_Status/ps.log
# Example of without relative path:
#   ns_ftp_file /tmp/date.txt
#   This file will ftp as "TRXXX/server_logs/<server_name>/<Monitor name>/date.txt"
####Some other possible cases for ftp file
#ns_ftp_file <Source file name> [<Destination file with relative/absolute path>]
#   ns_ftp_file /tmp/test.txt 
#   ns_ftp_file /tmp/test.txt .
#   ns_ftp_file /tmp/test.txt test.txt
#   ns_ftp_file /tmp/test.txt ps.log
#   ns_ftp_file /tmp/test.txt process/
#   ns_ftp_file /tmp/test.txt process/. 
#   ns_ftp_file /tmp/test.txt process/ps.log
#   ns_ftp_file /tmp/test.txt abc/xyz/
#   ns_ftp_file /tmp/test.txt abc/xyz/ps.log
#   ns_ftp_file /tmp/test.txt /abc/xyz/ps.log
#   ns_ftp_file /tmp/test.txt /abc

ns_ftp_file()
{
  SOURCE_PATH="$1"
  DEST_PATH="$2"
  MODE="$3"

  if [ "XX$SOURCE_PATH" = "XX" ];then
    ns_log_event "Major" "Error: File Name not given for ftp."
    return 1
  fi

  if [ ! -f $SOURCE_PATH ];then
    ns_log_event "Major" "Error: File '$SOURCE_PATH' does not exist for FTP."
    return 1
  fi

  FILE_NAME=`basename $SOURCE_PATH`
  FILE_SIZE=`ls -l $SOURCE_PATH | awk '{print $5}'`

  #Now in 3.5.1 we will support absolute path also so comment following lines
  #Check absolute path Ex: "/process/status.log" --- Wrong format
#  echo $DEST_PATH | grep ^/ >/dev/null
#  if [ $? = 0 ]; then
#    ns_log_event "Major" "Error: FTP Destination File name can have relative path only."
#    return 1
#  fi

  if [ "XX$DEST_PATH" = "XX" -o "XX$DEST_PATH" = "XX." -o "XX$DEST_PATH" = "XX$FILE_NAME" ];then
    if [ "XX$MODE" == "XX" ];then
      echo "FTPFile:$FILE_NAME:$FILE_SIZE"
    else
      echo "FTPFile:$FILE_NAME:$FILE_SIZE:$MODE"
    fi
  else
    #Check if given as "monitor_status/process/"
    echo $DEST_PATH | grep /$ >/dev/null
    if [ $? = 0 ]; then
      if [ "XX$MODE" == "XX" ];then
        echo "FTPFile:$DEST_PATH$FILE_NAME:$FILE_SIZE"
      else
        echo "FTPFile:$DEST_PATH$FILE_NAME:$FILE_SIZE:$MODE"
      fi  
    else
      #Check if given as "monitor_status/process/."
      echo $DEST_PATH | grep "\.$" >/dev/null
      if [ $? = 0 ]; then
        if [ "XX$MODE" == "XX" ];then
          echo "FTPFile:`dirname $DEST_PATH`/$FILE_NAME:$FILE_SIZE"
        else
          echo "FTPFile:`dirname $DEST_PATH`/$FILE_NAME:$FILE_SIZE:$MODE"
        fi
      else
        if [ "XX$MODE" == "XX" ];then
          echo "FTPFile:$DEST_PATH:$FILE_SIZE"
        else
          echo "FTPFile:$DEST_PATH:$FILE_SIZE:$MODE"
        fi
      fi
    fi
  fi
  cat $SOURCE_PATH
  return 0
}

#This method is to ftp file for server signature
#ns_ftp_file_for_server_sig <File name for ftp> <Signature name.ssf>
#This will FTP 'file' or 'command' output as "Signature Name.ssf" in TRXXXX/server_signatures/ directory
ns_ftp_file_for_server_sig()
{
  FILE_NAME_FOR_FTP="$1"
  SIGNATURE_FILE="$2"
  if [ "XX$FILE_NAME_FOR_FTP" = "XX" -o "XX$SIGNATURE_FILE" = "XX" ];then
    ns_log_event "Major" "File Name or signature name not given for ftp."
    return 1
  fi
  if [ ! -f $FILE_NAME_FOR_FTP ];then
    ns_log_event "Major" "File '$FILE_NAME_FOR_FTP' does not exist for FTP."
    return 1
  fi
  FILE_SIZE=`ls -l $FILE_NAME_FOR_FTP | awk '{print $5}'`
  echo "FTPFile:$SIGNATURE_FILE:$FILE_SIZE"
  cat $FILE_NAME_FOR_FTP
  return 0
}

#Check if test is over or not
# Argument: Test run number (e.g. 1234)
# Returns:
#   0 - Not over
#   1 - Test is  over
isTestOver()
{
  TEST_RUN=$1

  # This is to allow testing from command line as test may not be running and TEST_RUN is not set
  if [ "X$TEST_RUN" = "X" ];then
    # Test is not over
    return 0
  fi

  #This is to differentiate running tests in case of test stop-start in continuous monitoring.
  #$MON_PARTITION_IDX will be -1 or 0 in NS mode and will have a positive number in case of continuous monitoring.
  if [ "$MON_PARTITION_IDX" = "-1" -o "$MON_PARTITION_IDX" = "0" -o "X$MON_PARTITION_IDX" = "X" ]; then
    RUNNING_TEST_FILE=$CAV_MON_HOME/logs/running_tests/$TEST_RUN
  else
    RUNNING_TEST_FILE=$CAV_MON_HOME/logs/running_tests/${TEST_RUN}_${MON_PARTITION_IDX}
  fi

  if [ ! -f $RUNNING_TEST_FILE ];then
    # Test is over
    return 1
  fi

  # Test is not over
  return 0
}

ns_check_mon_pass_and_exit()
{
 echo "CheckMonitorStatus:Pass"
 exit 0
}

ns_check_mon_fail_and_exit()
{
 echo "CheckMonitorStatus:Fail"
 exit 255
}

# This method gets OS arch data model.
# OS is 32 or 64 bits
# TODO. Logic is not fool proof. We need to make it better
# It is assuming is machine CPU is 64 bit then OS is 64 bits which is not always true
# as we can install 32 bit linux in 64 bit CPU machine.

get_os_arch_data_model()
{
  MACHINE_BIT=`uname -m`
  
  #Manish: x86_64 for linux, aix and solaris
  #        ia64 for HPUX
  if [ $MACHINE_BIT = "x86_64" -o $MACHINE_BIT = "ia64" ]; then
    OS_ARCH_DATA_MODEL=64
  else
    OS_ARCH_DATA_MODEL=32
  fi
}

#This function is used to calculate relative data. (current - initial)
#This is called from all the monitors where we are computing cumulative values.
#NOTE: Make sure this function has no echo commands.
get_relative_value()
{
CURRENT_VALUE=$1
INITIAL_VALUE=$2
MON_NAME=$3
FIELD_NAME=$4

  # 8 bytes data cannot be checked using less than due to shell limitation if data value is more than max value of 4 bytes
  # As a quick fix, we are using bc to take diff and see if diff is -ve or not
  # If -ve, then counter is overflowing.
  if [ $BC_AVAILABLE -eq 1 ];then 
    RELATIVE_VALUE=`echo "$CURRENT_VALUE - $INITIAL_VALUE" | bc -l`
  else
    RELATIVE_VALUE=`awk -v "var1=$CURRENT_VALUE" -v "var2=$INITIAL_VALUE" 'BEGIN{printf "%ld", (var1 - var2)}'`
  fi
  SIGN=`echo "$RELATIVE_VALUE" | cut -c 1`

  if [ "X$SIGN" = "X-" ];then  # -ve. So over flow is to be handled
    if [ "X$OS_ARCH_DATA_MODEL" = "X32" ];then
      if [ $BC_AVAILABLE -eq 1 ];then
        RELATIVE_VALUE=`echo "$MAX_UNSIGNED_LONG_32 - $INITIAL_VALUE + $CURRENT_VALUE" | bc -l`
      else
        RELATIVE_VALUE=`awk -v "var1=$MAX_UNSIGNED_LONG_32" -v "var2=$INITIAL_VALUE" -v "var3=$CURRENT_VALUE" 'BEGIN{printf "%ld", (var1-var2+var3)}'`
      fi
    else
      if [ "X$FIELD_NAME" != "XNA" ];then
        ns_log_event "Major" "Counter for $FIELD_NAME in monitor $MON_NAME overflowed in 64 bits OS. Current value is $CURRENT_VALUE and previous value is $INITIAL_VALUE"
      else
        ns_log_event "Major" "Counter in monitor $MON_NAME overflowed in 64 bits OS. Current value is $CURRENT_VALUE and previous value is $INITIAL_VALUE"
      fi
    
    RELATIVE_VALUE=$CURRENT_VALUE
    fi
  fi
   echo $RELATIVE_VALUE
}

#Set CAV_MON_TMP_DIR if not set already 
if [ "X$CAV_MON_TMP_DIR" = "X" ]; then
    # Since on many OS expor command not run in one line like
    # export CAV_MON_TMP_DIR="$CAV_MON_HOME/logs"
    # So split in two parts 
    CAV_MON_TMP_DIR="$CAV_MON_HOME/logs"
    export CAV_MON_TMP_DIR
fi

#Set MON_FREQUENCY if not set already
#setting MON_FREQUENCY to 10 secs in two steps to handle error:
#/opt/cavisson/monitors/bin/ns_check_monitor_func.sh: line 305: [: -gt: unary operator expected
if [ "X$MON_FREQUENCY" = "X" ]; then
  #setting default 10 secs
  MON_FREQUENCY=10
elif [ $MON_FREQUENCY -gt 0 ];then
  #convert in secs
  if [ $BC_AVAILABLE -eq 1 ];then 
    MON_FREQUENCY=`echo " $MON_FREQUENCY / 1000" | bc`
  else
    MON_FREQUENCY=`awk -v "var1=$MON_FREQUENCY" 'BEGIN{printf "%d", (var1/1000)}'`
  fi
else
  #again setting default 10 secs to handle case:
  # MON_FREQUENCY=0
  # MON_FREQUENCY=negative
  MON_FREQUENCY=10
fi
export MON_FREQUENCY

if [ "X$MON_VECTOR_SEPARATOR" = "X" ]; then
  MON_VECTOR_SEPARATOR=">"
fi
export MON_VECTOR_SEPARATOR

#This is to check:
#     (1)if file exists or not, from which monitor is reading for output
#     (2)if command is still running or not 
#     (3)if file is appending or not
#If file does not exists or command not running or file is not appending then exit monitor and in this case connection retry logic will work.
is_mon_file_cmd_exists()
{
  FILE=$1 
  CMD=$2
  MonName=$3

  CUR_MON_FILE_SIZE=`stat --printf %s $FILE 2>/dev/null`
  if [ $? -ne 0 ]; then
    ns_log_event "Major" "$MonName($VECTOR_NAME): Output file ($FILE) of command ($CMD) does not exist. It may be removed"
    exit 1
  fi
  
  #if file not appending 
  if [ $CUR_MON_FILE_SIZE -le $PREV_MON_FILE_SIZE ]; then  
    ns_log_event "Major" "$MonName($VECTOR_NAME): Data is not appending in output file ($FILE) of command ($CMD). Either command is no longer running or disk is full"
    exit 1
  fi

  PREV_MON_FILE_SIZE=$CUR_MON_FILE_SIZE
}

lib_set_ps_cmd()
{
  OS_NAME=`uname`
  if [ "X$OS_NAME" = "XSunOS" ]; then
    LIB_PS_CMD_FOR_DATA="/usr/bin/ps"
    if [ ! -f /usr/ucb/ps ];then
      echo "Error: ps command not found on path /usr/ucb/ps. Hence standard ps command will be used."
      LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
    else
      LIB_PS_CMD_FOR_SEARCH="/usr/ucb/ps -auxwww"
    fi
    if [ ! -f /usr/xpg4/bin/grep ];then
      echo "Error: grep command not found on path /usr/xpg4/bin/grep. Hence extended regular expression may not be supported."
      LIB_PS_GREP_CMD="/usr/bin/egrep -e"  #Search for a pattern_list(full regular expression that 
                                       #begins with a -).
   else
     LIB_PS_GREP_CMD="/usr/xpg4/bin/grep -E"
   fi
   LIB_AWK="nawk" #In SUN OS awk not support -v option
  else #Linux,AIX
    LIB_PS_CMD_FOR_DATA="ps"
    LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
    #PS_GREP_CMD="grep -e"
    LIB_PS_GREP_CMD="grep -E"      # Fixed bug: 4574
   LIB_AWK="awk"
  fi
}

KILL_LOG_FILE=$CAV_MON_HOME/logs/CavMonAgentTrace.log

lib_trace_log()
{
  CALLING_FUN_NAME=$1
  MSG=$2

  if [ "X$MON_TEST_RUN" = "X" ];then
    MON_TEST_RUN="NA"
  fi

  if [ "X$CALLING_FUN_NAME" = "X" ];then
    CALLING_FUN_NAME="NA"
  fi

  DATE_TIME_FORMAT="`date +'%m/%d/%y %R'`|$MON_TEST_RUN|$CALLING_FUN_NAME"
  echo "$DATE_TIME_FORMAT|$MSG" >>$KILL_LOG_FILE
}

#If someone stop cmon forcefully then read fails and monitors stuck in read like infinite loop
#due to this CPU becomes busy 
#To avoid this we need to add timer on read
lib_sleep()
{
  sleep_time_in_secs=$1

  # In Sun OS date command is not run as used here so (for Market Live) currently we are using sleep insted of read
  # TODO: Find solution for sun os
  OS_NAME=`uname`
  if [ "XX$OS_NAME" = "XXSunOS" ];then
    sleep $sleep_time_in_secs
  else
    # %s     seconds since 1970-01-01 00:00:00 UTC
    before_read_time=`date +'%s'`
    read -t $sleep_time_in_secs >/dev/null 2>&1
    after_read_time=`date +'%s'`
    elap_time=`expr $after_read_time - $before_read_time`
    if [ $elap_time -lt $sleep_time_in_secs ];then
      left_freq=`expr $sleep_time_in_secs - $elap_time`
      sleep $left_freq
    fi
  fi
}

lib_normal_kill_process()
{ 
  pid=$1
  
  lib_trace_log "$CALLING_FUN_NAME" "lib_normal_kill_process(), Method called, pid = $pid"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? != 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor process/child whose PID = $pid is already stopped" 
    return
  fi

  kill $pid  2>/dev/null
}

lib_post_kill_process()
{ 
  pid=$1
  
  lib_trace_log "$CALLING_FUN_NAME" "lib_post_kill_process(), Method called, pid = $pid"
  name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' | tail -1 2>&1`
  lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? = 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor with PID = $pid and parent pid, start time and args = $name still Running. Attempting to Kill using -9 .... "
    kill -9 $pid 2>&1
    if [ $? = 0 ]; then
     lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name killed successfully."
    fi
  else 
    lib_trace_log "$CALLING_FUN_NAME" "PID = $pid killed successfully in normal kill. "
  fi
}

lib_kill_process()
{ 
  pid=$1
  if [ "X$pid" == "X" ];then
    return
  fi
 
  name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' | tail -1 2>&1`

  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? != 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor process/child whose PID = $pid is already stopped"
    return
  fi

  kill $pid  2>/dev/null

  lib_sleep 2
  lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? = 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor with PID = $pid and parent pid, start time and args = $name still Running. Attempting to Kill using -9 .... "
    kill -9 $pid 2>&1
    if [ $? = 0 ]; then
      lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name killed successfully."
    fi
  else 
    lib_trace_log "$CALLING_FUN_NAME" "PID = $pid killed successfully in normal kill."
  fi
}

GOOD_PID=0
#This function will check pid is good or not if pid is good then set GOOD_PID = 1 
is_good_pid()
{
  pid=$1
  GOOD_PID=0
  for fname in `ls $CAV_MON_HOME/logs/*.pid >/dev/null 2>&1`
  do
    NPID=`cat $fname 2>/dev/null`
    if [ "X$NPID" != "X" ];then
      if [ "X$NPID" = "X$pid" ];then
        GOOD_PID=1
        name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' | tail -1 2>&1`
        lib_trace_log "is_good_pid" "Process $KILL_PID is healthy whose parent pid, start time and args = $name."
        break
      fi
    fi
  done
}

lib_kill_process_using_pid_list()
{
  CALLING_FUN_NAME=$1
  PIDS=$2

  if [ "XX$PIDS" == "XX" ];then  
    lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list(): Provided pid list is empty, Hence returning..."
    return 
  fi

  pid_idx=0
  for pid in `echo $PIDS`
  do
    pid_list[$pid_idx]=$pid
    pid_idx=`expr $pid_idx + 1`
  done

  lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list Method called, pid_list = [${pid_list[@]}]"
  
  lib_set_ps_cmd

  for KILL_PID in ${pid_list[@]} 
  do
    is_good_pid $KILL_PID 
    if [ "X$GOOD_PID" = "X0" ]; then 
      lib_normal_kill_process "$KILL_PID"
    fi
  done

  lib_trace_log "$CALLING_FUN_NAME" "Sleeping for 2 sec....."
  lib_sleep 2
  for KILL_PID in ${pid_list[@]} 
  do
    is_good_pid $KILL_PID 
    if [ "X$GOOD_PID" = "X0" ]; then 
      lib_post_kill_process "$KILL_PID"
    fi
  done
}

lib_kill_process_using_pid ()
{
  CALLING_FUN_NAME=$1
  PROCESS_PID=$2
  
  lib_set_ps_cmd

  for KILL_PID in `echo $PROCESS_PID`
  do
    GOOD_PID=0
    for fname in `ls $CAV_MON_HOME/logs/*.pid >/dev/null 2>&1`
    do
      NPID=`cat $fname 2>/dev/null`
      if [ "X$NPID" != "X" ];then
        if [ "X$NPID" = "X$KILL_PID" ];then
          GOOD_PID=1
          name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' | tail -1 2>&1`
          lib_trace_log "$CALLING_FUN_NAME" "Process $KILL_PID is healthy whose parent pid, start time and args = $name."
          break
        fi
      fi
    done
    
    if [ "X$GOOD_PID" = "X0" ]; then 
      lib_kill_process "$KILL_PID"
    fi

  done
}

#Manish:  Getting process tree and kill all process from leaf node
lib_get_childs_pid()
{
  psT_idx=$1
  ppid=$2
  #echo "psT_idx = [$psT_idx], ppid = [$ppid]" >>/tmp/kill_mon_log
  # We are not using ps --ppid to get child pid Because it will contain pid kill_monitor (self pid).
  # since ps --ppid not give args so it is complex to remove it self pid from child list 
  # In future we get a better method to find out child pids 
  #ps_tree[$psT_idx]=`ps -o pid --no-headers --ppid $ppid |  awk -F"\n" '{printf $1" "}'`
  ps_tree[$psT_idx]=`$LIB_PS_CMD_FOR_DATA -ef | $LIB_PS_GREP_CMD -v kill_monitor | $LIB_PS_GREP_CMD -v grep | awk '$3 == '$ppid' {printf $2" "}'`
#  echo "[$psT_idx]    : [$ppid]  -> ${ps_tree[$psT_idx]}" >>/tmp/kill_mon_log 
  psT_idx=`expr $psT_idx + 1`
}

check_break()
{
#  echo "check_break(): Method called, ps_idx = $ps_idx, psT_idx = $psT_idx" >>/tmp/kill_mon_log

  ps_idx=`expr $ps_idx + 1`

  if [ $ps_idx -eq $psT_idx -o $ps_idx -gt $psT_idx ]; then
    break
  fi
}

# Input  - process id whose process tree we want ro see
# Output - return child pids from leaf to node order (right to left)
#          Eg:   ppid   -> pids(of ppid)
#          Eg:   p1     -> p1.c1 p1.c2 p1.c3
#                p1.c1  -> p1.c1.c1 p1.c1.c2  
#                p1.c2  -> p1.c2.c1 p1.c2.c2 p1.c2.c3
#          Output of above tree-
#          p1.c2.c3 p1.c2.c2 p1.c2.c1 p1.c1.c2 p1.c1.c1 p1.c3 p1.c2 p1.c1 
#          |------------------------| |---------------| |---------------|
#                leaf node                 leaf node     intermedit node
#Info : To see process tree we also have command in linux
#       pstree -p <pid>  [for more information see man page]
#Note: - here it is assumend that exception list will be passed as comma seperated 
#        Eg: 1234,345,89
lib_get_proc_tree()
{
  proc_id=$1
  CALLING_FUN_NAME=$2
  psT_idx=0
  final_pid_list=""
  ignored_pid_list=""

  lib_trace_log "$CALLING_FUN_NAME" "Method lib_get_proc_tree() called., CALLING_FUN_NAME=[$CALLING_FUN_NAME], proc_id=[$proc_id], excp_list = [$3]" 

  lib_set_ps_cmd

  if [ "X$proc_id" = "X" ];then
    lib_trace_log "$CALLING_FUN_NAME" "proc_id should not be empty."
    echo ""
    exit 1
  fi

  #check proc id must be integer
  echo $proc_id | grep '^[0-9]*$' 2>&1 >/dev/null
  if [ $? != 0 ];then
    lib_trace_log "$CALLING_FUN_NAME" "proc_id $proc_id must be a numeric number"
    echo ""
    exit 1
  fi

  kill_excp_pid_list=`echo $3 | $LIB_AWK -F',' '{ for ( i = 1; i <= NF; i++) printf $i" "}'`

  lib_get_childs_pid $psT_idx $proc_id
  
  lib_trace_log "$CALLING_FUN_NAME" "Before ignoring exception pids child of pid $proc_id is - ${ps_tree[$ps_idx]}"

  ps_idx=0

  # Remove all childs of root pid which are in exception list Hence re-arrange ps_tree for index 0 
  if [ "X$kill_excp_pid_list" != "X" ];then
    lib_trace_log "$CALLING_FUN_NAME" "Checking pids of exception list to ignore for killing"
    for root_child_pid in `echo ${ps_tree[$ps_idx]}`; do
      found=0
      for excp_pid in `echo $kill_excp_pid_list`; do
        if [ $root_child_pid == $excp_pid ]; then
          lib_trace_log "$CALLING_FUN_NAME" "Pid $excp_pid is in exception list hence ignoring this pid."
          found=1
          #final_pid_list=$final_pid_list" "$root_child_pid
        #else
        #  ignored_pid_list=$ignored_pid_list" "$root_child_pid
        fi
      done
      if [ $found -eq 0 ];then
        lib_trace_log "$CALLING_FUN_NAME" "Add pid $root_child_pid in final pid list"
        final_pid_list=$final_pid_list" "$root_child_pid
      else
        lib_trace_log "$CALLING_FUN_NAME" "Add pid $root_child_pid in ignore pid list"
        ignored_pid_list=$ignored_pid_list" "$root_child_pid
      fi
    done  
    lib_trace_log "$CALLING_FUN_NAME" "final_pid_list = $final_pid_list, ignored_pid_list = $ignored_pid_list"
    ps_tree[$ps_idx]="$final_pid_list"
  fi

  lib_trace_log "$CALLING_FUN_NAME" "After ignoring exception pids child of pid $proc_id is - ${ps_tree[$ps_idx]}"

  while true
  do 
    num_childs=0
    num_childs=`echo ${ps_tree[$ps_idx]} | $LIB_AWK -F' ' '{print NF}'`
#    echo "num_childs = $num_childs" >>/tmp/kill_mon_log
    if [ $num_childs -eq 0 ];then
      check_break
      continue
    fi

    i=1
    while true
    do 
      pid=`echo ${ps_tree[$ps_idx]} | $LIB_AWK -F' ' -v id=$i '{print $id}'`
      lib_get_childs_pid $psT_idx $pid

      if [ $i -eq $num_childs ]; then
        break
      fi

      i=`expr $i + 1`
    done

    check_break
  done

  #Making child list
  #Remove multiple spaces from ps_tree
  child_pid_list=`echo ${ps_tree[@]} | sed 's/[ ]/ /g'`
  
  ############ Code for logging only ##########
  lib_trace_log "$CALLING_FUN_NAME" "***------------------------------ Process Tree Of Pid $proc_id ---------------------------------------***"
  lib_trace_log "$CALLING_FUN_NAME" "All childs of pid($proc_id) child_pid_list = [$child_pid_list]"
  lib_trace_log "$CALLING_FUN_NAME" " " 
  #Since in Sun OS --forest is not applicable show we return from here 
  OS_NAME=`uname`
  lib_trace_log "$CALLING_FUN_NAME" "OS_NAME = [$OS_NAME]"
  #Since in Sun OS --forest is not applicable show we return from here 
  if [ "X$OS_NAME" = "XSunOS" ]; then
    #space with -p option gives error 
    if [ "X$child_pid_list" = "X" ]; then
      $LIB_PS_CMD_FOR_DATA -p "$proc_id" -o 'pid ppid stime args' >>$KILL_LOG_FILE
    else
      $LIB_PS_CMD_FOR_DATA -p "$proc_id $child_pid_list" -o 'pid ppid stime args' >>$KILL_LOG_FILE
    fi
  else
    #space with -p option gives error 
    if [ "X$child_pid_list" = "X" ]; then
      $LIB_PS_CMD_FOR_DATA -p "$proc_id" -o 'pid ppid stime args' --forest >>$KILL_LOG_FILE
    else
      $LIB_PS_CMD_FOR_DATA -p "$proc_id $child_pid_list" -o 'pid ppid stime args' --forest >>$KILL_LOG_FILE
    fi
  fi
  lib_trace_log "$CALLING_FUN_NAME" "***------------------------------ xxxxxxxxxxxxxxxxxxxxxxxxxxxx ---------------------------------------***"
  ############ Code for logging complete ##########

  # If there is any ignored pid then check its is running or not if not then clean their respective file
  if [ "XX$ignored_pid_list" != "XX" ];then
    for ing_pid in `echo $ignored_pid_list` 
    do 
      $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
      if [ $? != 0 ]; then
        lib_trace_log "$CALLING_FUN_NAME" "PID = $ing_pid is not running hence removing their repective pid file from dir log dir"
        rm -f $CAV_MON_HOME/logs/$EXCP_PID_DIR/$ing_pid 
      fi
    done
  fi

  # Since we need kill process from leaf node so return child pids in reverse order
  #Manish: Note - this echo produce output so don't redirect it into any file
  echo $child_pid_list |  $LIB_AWK '{ for ( i = NF; i > 0; i--) printf $i" "}'
}

set_mon_shell()
{
  OS_NAME=`uname`

  if [ "X$UNIX_SHELL" = "X" ]; then
    if [ "X$OS_NAME" = "XSunOS" ]; then
      UNIX_SHELL="/bin/bash"
    elif [ "X$OS_NAME" = "XHPUX" ]; then
      UNIX_SHELL="/usr/bin/ksh"
    #When we install cmon on heroku machine, nsi_kill_child shell exits because default shell is 'sh'.
    #ORIGIN_CMON var holds heroku identifier on heroku machine.
    elif [ "X$ORIGIN_CMON" != "X" ]; then
      UNIX_SHELL="/bin/bash"
    fi
  fi

  #echo "In set_mon_shell, UNIX_SHELL set to $UNIX_SHELL" >> $KILL_LOG_FILE
  export UNIX_SHELL
}

#This method will create the command as below mentioned
#eval ps -ef  |grep -E  nsi_memory_leakage_int  |grep -E  "\-u root"  |grep -E  "\-p 1862"

lib_set_command_for_search()
{
  i=0
  LOC_MULTIPLE_SEARCH_CMD=""
  lib_set_ps_cmd
  debug_log "Calling method set_command_for_search()"

  LOC_MULTIPLE_SEARCH_CMD=""

  while [ $i -lt $search_count ]
  do
   LOC_MULTIPLE_SEARCH_CMD=`echo "$LOC_MULTIPLE_SEARCH_CMD |$LIB_PS_GREP_CMD  ${SEARCH_PATTERN_ARR[$i]} "`
   #echo "*****$LOC_MULTIPLE_SEARCH_CMD*****"
   lib_trace_log "**[LOC_MULTIPLE_SEARCH_COMMAND] = $LOC_MULTIPLE_SEARCH_CMD]**"
   i=`expr $i + 1`
  done

  #if nsu_server_admin is running on same server, then it is also killed, hence skipping it
  LOC_MULTIPLE_SEARCH_CMD="$LOC_MULTIPLE_SEARCH_CMD | $LIB_PS_GREP_CMD -v nsu_server_admin"
  LIB_PS_CMD_FOR_SEARCH="eval $LIB_PS_CMD_FOR_SEARCH $LOC_MULTIPLE_SEARCH_CMD"
  lib_trace_log "**[LIB_PS_CMD_FOR_SEARCH= $LIB_PS_CMD_FOR_SEARCH]**"
}

#Note: since this function will return pid list by pattern hence there is no echo in this method. 
#This method will store the differnt arguments for shell and store them in the array
lib_get_ps_id_by_pattern()
{
  search_count=0
  CALLING_FUN_NAME=$1

  shift
  CALLER_NAME=$1

  while [ "XX$CALLER_NAME" != "XX" ];do
   SEARCH_PATTERN_ARR[$search_count]=$CALLER_NAME
   #echo "array list ${SEARCH_PATTERN_ARR[$search_count]}"
   search_count=`expr $search_count + 1`
   shift
   CALLER_NAME=$1
  done
  lib_set_command_for_search
  #PID will be generated here
  echo `$LIB_PS_CMD_FOR_SEARCH | grep -v cmon_client_utils.jar | $LIB_AWK -F' ' '{printf $2" "}'`
}


#This method get pid, check whether pid is running , if not then return else kill child and then process_id
lib_kill_ps_tree_by_pattern()
{
  CALLING_FUN_NAME=$1
  PID_LIST=`lib_get_ps_id_by_pattern "$@"`
  lib_trace_log "$CALLING_FUN_NAME" "PID_LIST=[$PID_LIST]"
  #echo "PID_LIST = $PID_LIST"  
  SELF_PID=$$
  PARENT_PID=$PPID
  if [ "X$PID_LIST" == "X" ];then
   return
  else
    for p_pid in `echo $PID_LIST`
    do
      if [ $p_pid == $SELF_PID ]; then
        lib_trace_log "$CALLING_FUN_NAME" "Self p_pid $p_pid , continue"
        continue
      fi
      if [ $p_pid == $PARENT_PID ]; then
        lib_trace_log "$CALLING_FUN_NAME" "Parent p_pid $p_pid , continue"
        continue
      fi
      ps -p $p_pid >/dev/null
      if [ $? -ne 0 ];then
        lib_trace_log  "$CALLING_FUN_NAME" "Process $p_pid is not running."
        #echo "Process $pid is not running."
        continue
      fi
      #echo "Killing childs of process $pid"
      lib_trace_log "$CALLING_FUN_NAME" "Killing childs of process $p_pid"
      lib_kill_process_using_pid_list `lib_get_proc_tree "$p_pid" "$CALLING_FUN_NAME"`

      #echo "Now killing parent pid $pid"
      lib_trace_log "$CALLING_FUN_NAME" "Now killing parent pid $p_pid."
      # Killing Parent (Till now all childs has been killed) 
      lib_kill_process "$p_pid"
    done
  fi
}

EXCP_PID_DIR=".kill_excp_pids"
add_pid_in_excp_list()
{
  epid=$1 

  mkdir -p $CAV_MON_HOME/logs/$EXCP_PID_DIR
  lib_trace_log  "NA" "Going to add $epid into exception list. Process is `$LIB_PS_CMD_FOR_DATA -p "$epid" -o 'pid ppid stime args'`"
  echo "" > $CAV_MON_HOME/logs/$EXCP_PID_DIR/$epid 
}

remove_pid_from_excp_list()
{
  epid=$1 

  lib_trace_log  "NA" "Going to remove $epid from exception list."
  rm -f $CAV_MON_HOME/logs/$EXCP_PID_DIR/$epid 
}

get_excp_pid_list()
{
  lib_set_ps_cmd

  excp_pid_list=`ls $CAV_MON_HOME/logs/$EXCP_PID_DIR 2>/dev/null` 

  echo $excp_pid_list | $LIB_AWK '{ for ( i = NF; i > 0; i--) printf $i","}'
}
