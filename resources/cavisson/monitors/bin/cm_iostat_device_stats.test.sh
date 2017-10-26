#Purpose: To test the monitor cm_iostat_device_stats for Solaris simulation
 
show_output()
{
echo "                    extended device statistics              "
echo "    r/s    w/s   kr/s   kw/s wait actv wsvc_t asvc_t  %w  %b device"
echo "    $rs1    4.7   43.5  196.1  0.0  0.0    0.1    7.7   0   1.1 c2t9d0"
echo "    $rs2    4.5   43.7  196.9  0.0  0.0    0.1    7.2   0   1.2 c2t10d0"
#echo "    12.4    4.4   43.5  196.1  0.0  0.0    0.1    7.2   0   1.3 c2t11d0"
#echo "    13.4    4.5   43.5  196.9  0.0  0.0    0.1    8.1   0   1.3 c2t8d0"
#echo "    14.0   13.0    2.2  252.9  0.0  0.1    0.0    9.1   0   1.4 c0t0d0"
#echo "    15.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   1.5 c0t1d0"
#echo "    16.0    0.5    0.0   31.9  0.0  0.0    0.0    1.6   0   1.6 c1t50060E8005488751d59"
echo "    $rs3    10.0   90.4    0.0  0.0  0.0    0.2    3.1   0   1.7 isg-sedaris:/dbexports"
}

freq=$1

rs1=10
rs2=20
rs3=30

show_output_periodicaly()
{
   while true
   do
     show_output
     lib_sleep $freq
     rs1=`expr $rs1 + 1`
     rs2=`expr $rs2 + 1`
     rs3=`expr $rs3 + 1`
   done

}

if [ "X$freq" != "X" ];then
  show_output_periodicaly
else 
  show_output
fi

exit 0
