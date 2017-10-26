#!/usr/bin/python
#########################################################################################################################
#Purpose:This is python monitor library currently used by cm_vmware_stats
#Author:Pitphilai Pandey
#Date:26-oct-2015
#########################################################################################################################
import os
import os.path
def isTestOver( TEST_RUN ):
  MON_PARTITION_IDX = os.environ['MON_PARTITION_IDX']
  CAV_MON_HOME = os.environ['CAV_MON_HOME']
#  print CAV_MON_HOME
  if TEST_RUN is None:
     return 0;
  if MON_PARTITION_IDX == "-1" or MON_PARTITION_IDX == "0" or MON_PARTITION_IDX is None:
    RUNNING_TEST_FILE = CAV_MON_HOME + "/logs/running_tests/" + TEST_RUN 
  else:
    RUNNING_TEST_FILE = CAV_MON_HOME + "/logs/running_tests/" + TEST_RUN + "_" + MON_PARTITION_IDX
 # print RUNNING_TEST_FILE
  if os.path.isfile(RUNNING_TEST_FILE):
    return 1;
  return 0;

#print isTestOver( TEST_RUN = "123")

