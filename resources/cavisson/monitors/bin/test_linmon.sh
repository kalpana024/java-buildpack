
# Purpsose : To Run TCPMON and LINMON
#Syntex : sh test_linmon.sh ../../../bin/monitors/linux/tcpmon 10000
#Syntex : sh test_linmon.sh ../../../bin/monitors/linux/linmon 10000


LINMON=$1
FREQ=$2


# Check for No. of arguments
if [ $# -lt 2 ];then
  echo "Error: Invalid number of arguments."
  exit 1
fi

if [ $# -gt 2 ];then
  echo "Error: Invalid number of arguments."
  exit 1
fi

# Check for frequency
if [ $FREQ -lt 1000 ];then
  echo "Error: Frequency should be greater than or equal to 1000"
  exit 1
fi

FREQ_SEC=`expr $FREQ / 1000`

while [ 1 = 1 ]
do
  echo -n "`date +%H:%M:%S`: "
  $LINMON $FREQ
  lib_sleep $FREQ_SEC
done
