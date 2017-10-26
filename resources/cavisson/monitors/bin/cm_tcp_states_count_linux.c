/*
 * Name   : cm_tcp_states_count_linux.c
 * Purpose: This will outputs count of IPV4 TCP states 
 * Output : Established SynSent SynRcvd FinWait1 FinWait2 TimeWait Closed CloseWait LastAck Listen Closing 
 *           2 0 0 0 0 0 0 0 0 13 0         
 * Author:  Prachi          
 * Initial version: date: 2013/04/06 
 * Modificaton    : date: 2013/04/09  -> added filtering
 */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <ctype.h>

#define MAX_BUF_SIZE 1024

#define ESTABLISHED_IDX 49
#define SYNSENT_IDX 50
#define SYNRCVD_IDX 51
#define FINWAIT1_IDX 52
#define FINWAIT2_IDX 53
#define TIMEWAIT_IDX 54
#define CLOSED_IDX 55
#define CLOSEWAIT_IDX 56
#define LASTACK_IDX 57
#define LISTEN_IDX 65
#define CLOSING_IDX 66

static char running_test_file[MAX_BUF_SIZE];
static int debug_level = 0;

//to store values given using option l/f
char local_and_foreign_ip_port[50][50];
char local_and_foreign_ip[50][50];
char local_and_foreign_port[50][50];

//to store values given using option e
char exclude_ip_and_port[50][50];
char exclude_ip[50][50];
char exclude_port[50][50];
int con_count_arr[127];   //total no. of characters 128

//Initializing interval to -1 so that further we can set interval to MON_FREQUENCY by checking -1
int interval = -1;  
//Initializing test_run to 0 so that further we can set test_run to MON_TEST_RUN by checking 0
int test_run = 0;
//partition_idx is used in continious monitoring to check if test is restarted.
long partition_idx =0;
char cav_mon_home[MAX_BUF_SIZE] = {0};

static void debug_log(int debug_level, char *format, ...)
{
  va_list ap;
  char buffer[MAX_BUF_SIZE + 1];
  int amt_written = 0;

  if(debug_level == 0)
    return;
  else
  {
    va_start (ap, format);
    amt_written = vsnprintf(buffer, MAX_BUF_SIZE, format, ap);
    va_end(ap);
    buffer[MAX_BUF_SIZE] = 0;
    fprintf(stdout, "%s\n", buffer);
  }
}

static void ns_log_event(char *severity, char *event_msg)
{
  fprintf(stdout, "Event:1.0:%s|%s\n", severity, event_msg);
  fflush(stdout);
}

static int isTestOver(int test_run)
{
  if(debug_level)
    debug_log(debug_level, "isTestOver() function called. test_run = %d, running_test_file = %s, debug_level = %d", test_run, running_test_file, debug_level);

  //This is to allow testing from command line as test may not be running and test_run is not set
  if(test_run == 0)
  {
    //Test is not over
    if(debug_level)
      debug_log(debug_level, "Test is not over.");
    return 0;
  }

  // Use access as it will be faster than fopen and fclose
  if(access(running_test_file, R_OK) < 0)
  {
    //Test is over
    if(debug_level)
      debug_log(debug_level, "Test is over.");
    return 1;
  }    

  //Test is not over
  if(debug_level)
    debug_log(debug_level, "Test is not over.");
  return 0;
}

static int get_tokens(char *read_buf, char *fields[], char *token, int max_flds)
{
  if(debug_level)
    debug_log(debug_level, "get_tokens() function called. read_buf = %s, token = %s, max_flds = %d, debug_level = %d", read_buf, token, max_flds, debug_level);

  int totalFlds = 0;
  char *ptr;
  char *token_ptr = NULL;

  ptr = read_buf;
  while((token_ptr = strtok(ptr, token)) != NULL)
  {
    ptr = NULL;
    totalFlds++;
    if(totalFlds > max_flds)
    {
      totalFlds = max_flds;
      break;
    }
    fields[totalFlds - 1] = token_ptr;
  }
  return(totalFlds);
}

static FILE *ipv4_fptr = NULL; // WE need to open once, so make it static
static FILE *ipv6_fptr = NULL; // WE need to open once, so make it static

char *ipv4_file_name ="/proc/net/tcp";
char *ipv6_file_name ="/proc/net/tcp6";

static void close_mon(int exit_value)
{
  if(ipv4_fptr)
  {
    if(fclose(ipv4_fptr) != 0)
    {
      ns_log_event("Critical", "Error in closing /proc/net/tcp file.");
    } 
  }

  if(ipv6_fptr)
  {
    if(fclose(ipv6_fptr) != 0)
    {
      ns_log_event("Critical", "Error in closing /proc/net/tcp6 file.");
    }
  }

  exit(exit_value);
}

/*Here we are tokenizing and storing input ip address into three different arrays ip_port/ip/port based on the input.
 * If input address is -> ip:port then will store this in array ip_port.
 * If input address is -> ip then will store this in array ip
 * Else if input address is -> port then will store this in array port 
 *
 * Tokenizing input ip address in three steps:
 * 1. comma(,) separated -> case of multiple comma separated input eg: 192.168.1.66:7891,192.168.1.49,127.0.0.1:1003
 * 2. colon(:) separated -> case of ip:port  eg: 192.168.1.66:2003
 * 3. dot(.) separated   -> case of ip only  eg: 127.0.0.1
 * 
 *Input to this function is: a. IP address given by user using option l/f/e 
 *                           b. Address of 3 arrays to store ip:port, ip and :port -> passing these addressess because we need store data                                             in different arrays based on the input. 
 *                              Eg:  with optios l/f -> will store in array local_and_foreign_ip_port, local_and_foreign_ip,local_and_foreign_port
 *                                   with option e   -> will store in array exclude_ip_and_port, exclude_ip, exclude_port
 *                           c.  Address of num_fields because we need no. of comma separated values for all the cases l/f/e for further executing for                                 loop in function get_and_show_data().
 * 
 * Output : Values in addressess passed to it.
 * */
static void set_ip_port(char *ip_port, char ip_port_in_hex[][50], char ip_in_hex[][50], char port_in_hex[][50], int *num_fields)
{
  char *comma_separated_field[50];
  char *colon_separated_field[50];
  char *dot_separated_field[50];

  char server_ip[46 + 1];
  int port = 0;

  int num_colon_separated_field = 0;
  int num_dot_separated_field = 0;

  int len = 0;           //length of port
  int s = 0;             //for "for loop" of comma separated values
  int k = 0;             //for "for loop" of dot separated values

  char buf_arry[4][10];  //array to temporarily store the dot separated values of ip address in Hex format
  char buf_port[10];     //array to temporarily store the port in Hex format

  if(debug_level)
    debug_log(debug_level, "set_ip_port() function called. ip_port = %s, debug_level = %d", ip_port, debug_level);

  server_ip[0] = '\0';

  memset(colon_separated_field, 0, sizeof(colon_separated_field));
  memset(comma_separated_field, 0, sizeof(comma_separated_field));
  memset(dot_separated_field, 0, sizeof(dot_separated_field));

  //if comma found then tokenizing based on comma.
  if(strstr(ip_port, ","))
    *num_fields = get_tokens(ip_port, comma_separated_field, ",", 50);
  else
  {
    //if comma not found then 0th index of comma_separated_field will point to input ip address
    //this is done because further we are executing for loop of *num_fields.
    comma_separated_field[0] = ip_port;
    *num_fields = 1;
  }

  //maximum 50 comma separated ip address can be given
  if(*num_fields > 50)
  {
    fprintf(stderr, "Error: Given comma separated values %d which is greater than maximum comma separated values 50.\n", *num_fields);
    close_mon(0);
  }

  //for loop of comma separated values.
  for(k = 0; k < *num_fields; k++)
  {
    //reset
    memset(buf_arry, 0, sizeof(buf_arry));
    memset(buf_port, 0, sizeof(buf_port));
    num_colon_separated_field = num_dot_separated_field = 0;

    //if colon found in any comma separated values then will tokenize it further into ip and port
    if(strstr(comma_separated_field[k], ":"))
    {
      num_colon_separated_field = get_tokens(comma_separated_field[k], colon_separated_field, ":", 50);

      //As we can give only port also in format (:port eg -> :7891) with options l/f/e
      //That's why checking num_colon_separated_field.
      if(num_colon_separated_field == 1)
      {
        //if dot is not found at 0th index of colon_separated_field then it means it is port in format :port 
        if(strstr(colon_separated_field[0], "."))
        {
          fprintf(stderr, "Invalid input format %s:\n",comma_separated_field[k]);
          close_mon(0);
        }
        port = atoi(colon_separated_field[0]);
      }
      else
      {
        //else it is in the format ip:port
        strcpy(server_ip, colon_separated_field[0]);
        port = atoi(colon_separated_field[1]);
      }
    }
    else
      strcpy(server_ip, comma_separated_field[k]);

    //further tokenizing ip by dot (.)
    if(strstr(server_ip, "."))
    {
      num_dot_separated_field = get_tokens(server_ip, dot_separated_field, ".", 50);
  
      for(s = 0; s < 4; s++)
      {
        sprintf(buf_arry[s], "%X", atoi(dot_separated_field[s]));

    /*set ip:port
     *IP addresses in /proc/net/
     *In the files offered by the /proc/net/ directory, IP addresses are often represented as little-endian four-byte hexadecimal numbers in following      format:
     *  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
     *   0: 00000000:006F 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 10067 1 ffff880137c106c0 299 0 0 2 -1
     *
     *
     *Hence for comparison we need to convert the input ip address from dotted-decimal notation to little-endian four-byte hexadecimal number.
     *For example, to convert the input remote address and port equivalent to the format given in file /proc/net/tcp, we'd do the following:
     *Let's separate the bytes of the address for readability:
     *127 0 0 1 : 23
     *Perform a simple decimal-to-hexadecimal conversion on each:
     *7F 00 00 01 : 0017
     *Reverse the ordering of the bytes in the IP address part:
     *0100007F:0017 */


        //storing each byte of IP in an array. so that it become easy to set the IP as little-endian four-byte hexadecimal numbers. 
        if(strlen(buf_arry[s]) == 1)
        {
          sprintf(buf_arry[s], "%d%X", 0, atoi(dot_separated_field[s]));
        }
        else
        {
          sprintf(buf_arry[s], "%X", atoi(dot_separated_field[s]));
        }
      }
    }
    if(port != 0)
    {
      sprintf(buf_port, "%X", port);
      len = strlen(buf_port);
      //converting port from decimal to hexadecimal.
      //Changing port value from format (ip:x, ip:xx, ip:xxx) -> (ip:000x, ip:00xx, ip:0xxx)
      if(len == 1)
        sprintf(buf_port, "%d%d%d%X", 0, 0, 0, port);
      else if(len == 2)
        sprintf(buf_port, "%d%d%X", 0, 0, port);
      else if(len == 3)
        sprintf(buf_port, "%d%X", 0, port);
      else
        sprintf(buf_port, "%X", port);
    }

    /*If input address in format ip:port then it means we have both the fields num_colon_separated_field & num_dot_separated_field hence store in           array ip_port in format ip:port
    * else if input address is ip only then it menas we have only single field num_dot_separated_field hence store in array ip in dotted format
    * else if input address is :port then it means we have only single field num_colon_separated_field hence store in array port
    * else we say input format is not correct. */
    if((num_colon_separated_field + num_dot_separated_field) == 6)
      sprintf(ip_port_in_hex[k], "%s%s%s%s:%s", buf_arry[3], buf_arry[2], buf_arry[1], buf_arry[0], buf_port);
    else if((num_colon_separated_field + num_dot_separated_field) == 4)
      sprintf(ip_in_hex[k], "%s%s%s%s", buf_arry[3], buf_arry[2], buf_arry[1], buf_arry[0]);
    else if((num_colon_separated_field + num_dot_separated_field) == 1)
      sprintf(port_in_hex[k], "%s", buf_port);
    else
    {
      fprintf(stderr, "Error: Invalid format.\n");
      close_mon(0);
    }

    if(debug_level)
      debug_log(debug_level, "set_ip_port() ip_port_in_hex[%d] = %s, ip_in_hex[%d] = %s, port_in_hex[%d] = %s", k, ip_port_in_hex[k], k, ip_in_hex[k] , k, port_in_hex[k]);
  }
}

//Split input address ip:port into ip and port 
static void save_ip_port(char *data, char *ip_port, char *ip, char *port)
{
  if(debug_level)
    debug_log(debug_level, "save_ip_port() function called. data = %s, debug_level = %d", data, debug_level);

  strncpy(ip_port, data, 13);
  ip_port[13] = '\0';
  strncpy(ip, data, 8);
  ip[8] = '\0';
  strncpy(port, data + 9, 4);
  port[4] = '\0';

  if(debug_level)
    debug_log(debug_level, "save_ip_port() function end. ip_port = %s, ip = %s, port = %s, debug_level = %d", ip_port, ip, port, debug_level);
}

#define STATE_OFFSET_IPv4 31
#define STATE_OFFSET_IPv6 79
#define LOCAL_IP_PORT_OFFSET_IPv4 2
#define LOCAL_IP_PORT_OFFSET_IPv6 26
#define REMOTE_IP_PORT_OFFSET_IPv4 16
#define REMOTE_IP_PORT_OFFSET_IPv6 65


static void init_mon()
{
  int mon_freq = -1;

  /* On some client machine we do not have /proc/net/tcp6 hence removed below check and 
   * checking this ptr is NULL or not while calling get_and_show_data(). 
   * So that we can give data of file which is present.
  */
  ipv4_fptr = fopen(ipv4_file_name, "r"); 
  ipv6_fptr = fopen(ipv6_file_name, "r");

  if ((ipv4_fptr == NULL) && (ipv6_fptr == NULL)) {
    ns_log_event("Critical", "Error in opening /proc/net/tcp and /proc/net/tcp6 files. Monitor data will not be available");
    close_mon(-1);
  }

  // interval is not passed, set this to MON_FREQUENCY
  if(interval == -1)
  {
    if(getenv("MON_FREQUENCY") != NULL)
      mon_freq = atoi(getenv("MON_FREQUENCY"));
    if(mon_freq > 0)
      interval = mon_freq / 1000; //ms -> sec

    if(interval < 1) // In case MON_FREQUENCY is not set or it is too low.
      interval = 1;
  }


  if(test_run == 0)
  {
    if(getenv("MON_TEST_RUN") != NULL)
      test_run = atoi(getenv("MON_TEST_RUN"));
  }
 
  if(strlen(cav_mon_home) == 0)
  {
    if(getenv("CAV_MON_HOME") != NULL)
      strcpy(cav_mon_home, getenv("CAV_MON_HOME"));
  }

  //in case of continious monitoring, if test restarts, monitors of last test may hang as they may find test running.
  //Hence parition idx will also be appended with TR num in running_test dir.
  //Then monitor can identify test stop-start and can kill itself.

  if(partition_idx <= 0)  //partition_idx is -1 if no partition is created in test
    sprintf(running_test_file, "%s/logs/running_tests/%d", cav_mon_home, test_run);
  else
    sprintf(running_test_file, "%s/logs/running_tests/%d_%ld", cav_mon_home, test_run, partition_idx);
    

  if(debug_level)
    debug_log(debug_level, "interval = [%d], test_run = [%d], cav_mon_home = [%s], running_test_file = [%s]", 
                            interval, test_run, cav_mon_home, running_test_file);  

}

//Read file proc/net/tcp line by line and increment connection states counters according to the options(l/f/e/no option) given
//and print value of all the possible connection states
static void get_and_show_data(FILE *fptr, int lflag, int fflag, int eflag, int local_foreign_ip_port, int exclude_ip_port, int state_offset,int local_ip_port_offset, int remote_ip_port_offset)
{
  char data_buf[MAX_BUF_SIZE];
  char *data;
  char ip_port[50];         //to temporarily store address read from file /proc/net/tcp in ip:port format
  char ip[20];              //to temporarily store ip read from file /proc/net/tcp
  char port[10];            //to temporarily store port read from file /proc/net/tcp 
  int idx = 0;              //for loop of num of comma separated values given using options l/f 
  int indx = 0;             //for loop of num of comma separated values given using options e
  int flag = 0;
  //char *ptr_to_colon = NULL;

  if(debug_level)
    debug_log(debug_level, "get_and_show_data() function called. debug_level = %d, ",
                           "state_offset = %d, local_ip_port_offset = %d, remote_ip_port_offset = %d", 
                            debug_level, state_offset, local_ip_port_offset, remote_ip_port_offset);

  if(fseek(fptr, 0, SEEK_SET) < 0)
  {
    ns_log_event("Critical", "Error in seeking /proc/net/tcp or tpc6 file. Monitor data will not be available");
    return;
  }

  //Read file two times 
  //1. For header
  fgets(data_buf, MAX_BUF_SIZE, fptr);

  //2. for data
  while (fgets(data_buf, MAX_BUF_SIZE, fptr) != NULL)
  {
    if(debug_level)
      debug_log(debug_level, "data_buf = [%s]", data_buf);
    //Format of file is:
    //For IPv4:
    //   0: 00000000:006F 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 10067 1 ffff880137c106c0 299 0 0 2 -1

    //For IPv6:
    //  45: 00000000000000000000000000000000:3AE8 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 15995 1 ffff8801381d2d00 299 0 0 2 -1

    /* In data array storing data after first colon i.e. after sequence number because seq no. can be of any length(bytes)
     * like 999, 9999, 99999, etc depending upon no. of connections.
     * Example: if data is: "450: 00000000:006F 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 10067 1 ffff880137c106c0 299 0 0 2 -1"
     * then will store ": 00000000:006F 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 10067 1 ffff880137c106c0 299 0 0 2 -1" 
     * */
    data = strstr(data_buf, ":");
    if(data == NULL)
    { 
      if(debug_level)
        debug_log(debug_level, "Obtained data [%s] without colon. Hence continue...", data_buf);
      continue;
    }

    // memmove (data, ptr_to_colon, strlen(ptr_to_colon));

    if(debug_level)
      debug_log(debug_level, "############################################## state = %d, lflag = %d, fflag = %d, local_ip_port_offset = %d, remote_ip_port_offset = %d, data= [%s]", (int)data[state_offset], lflag, fflag, local_ip_port_offset, remote_ip_port_offset, data);

    if(lflag)
      save_ip_port(data + local_ip_port_offset, ip_port, ip, port);
    else if(fflag)
      save_ip_port(data + remote_ip_port_offset, ip_port, ip, port);

     if(debug_level)
       debug_log(debug_level, "ip_port = [%s], ip = [%s], port = [%s]", ip_port, ip, port);

    /*                   Established SynSent SynRcvd FinWait1 FinWait2 TimeWait Closed CloseWait LastAck Listen Closing                   
     *Connection states: 01          02      03      04       05       06       07     08        09      0A     0B
     *                    |           |       |       |        |        |        |      |         |       |      |
     *                    V           V       V       V        V        V        V      V         V       V      V
     *ASCII values:       49          50      51      52       53       54       55     56        57      65     66 */

    //Here index of con_count_arr is ascii value of connection state.
    //Eg: ascii value of A is 65, hence we are incrementing counters for state "A" at index 65.

    //when only l/f option is given, increment counters for all the matches
    if(((lflag != 0) || (fflag != 0)) && (eflag == 0))
    {
      for(idx = 0; idx < local_foreign_ip_port; idx++)
      {
        if((!strcmp(ip_port, local_and_foreign_ip_port[idx])) || (!strcmp(ip, local_and_foreign_ip[idx])) || (!strcmp(port, local_and_foreign_port[idx])))
        {
          con_count_arr[(int)data[state_offset]]++;
        }
      }
    }
    else if(((lflag != 0) || (fflag != 0)) && (eflag != 0))
    {
      for(idx = 0; idx < local_foreign_ip_port; idx++)
      {
        flag = 0;
        if((!strcmp(ip_port, local_and_foreign_ip_port[idx])) || (!strcmp(ip, local_and_foreign_ip[idx])) || (!strcmp(port, local_and_foreign_port[idx])))
        {
          for(indx = 0; indx < exclude_ip_port; indx++)
          {
            //if read address found in any of the exclude array then set flag 
            //else keep it unset
            if(!(((strcmp(ip_port, exclude_ip_and_port[indx])) && (strcmp(ip, exclude_ip[indx])) && (strcmp(port, exclude_port[indx]))) != 0))
            {
              flag = 1;  //it means exclude it because found in exclude array
            }
          }
          if(flag == 0)  //it means include it because not found in exclude array
          {
            //Increment counters for only those input values using l/f, which are not given using e option.
            //means increment after excluding e option values.
            con_count_arr[(int)data[state_offset]]++;
          }
        }
      }
    }
    else if(((lflag == 0) || (fflag == 0)) && (eflag != 0))
    {
      for(indx = 0; indx < exclude_ip_port; indx++)
      {
        if(((strcmp(ip_port, exclude_ip_and_port[indx])) && (strcmp(ip, exclude_ip[indx])) && (strcmp(port, exclude_port[indx]))) != 0)
        {
          con_count_arr[(int)data[state_offset]]++;
        }
      }
    }
    else
    {
      //increment counters everytime if no l/f/e flag is specified
      con_count_arr[(int)data[state_offset]]++;
    }
  } 

}


void show_data()
{
  if(debug_level)
    debug_log(debug_level, "Method Called. ESTABLISHED_IDX = %d, SYNSENT_IDX = %d, SYNRCVD_IDX = %d, FINWAIT1_IDX = %d, FINWAIT2_IDX = %d," 
                           "TIMEWAIT_IDX = %d, CLOSED_IDX = %d, CLOSEWAIT_IDX = %d, LASTACK_IDX = %d, LISTEN_IDX = %d,"  
                           "CLOSING_IDX = %d\n", con_count_arr[ESTABLISHED_IDX], con_count_arr[SYNSENT_IDX], con_count_arr[SYNRCVD_IDX], 
                            con_count_arr[FINWAIT1_IDX], con_count_arr[FINWAIT2_IDX], con_count_arr[TIMEWAIT_IDX], con_count_arr[CLOSED_IDX], 
                            con_count_arr[CLOSEWAIT_IDX], con_count_arr[LASTACK_IDX], con_count_arr[LISTEN_IDX], con_count_arr[CLOSING_IDX]);
 
  if( printf("%d %d %d %d %d %d %d %d %d %d %d\n", con_count_arr[ESTABLISHED_IDX], con_count_arr[SYNSENT_IDX], con_count_arr[SYNRCVD_IDX], con_count_arr[FINWAIT1_IDX], con_count_arr[FINWAIT2_IDX], con_count_arr[TIMEWAIT_IDX], con_count_arr[CLOSED_IDX], con_count_arr[CLOSEWAIT_IDX], con_count_arr[LASTACK_IDX], con_count_arr[LISTEN_IDX], con_count_arr[CLOSING_IDX]) < 0 )
  {
    ns_log_event("Critical", "Error in writing output to stdout.");
    close_mon(-1);
  }

  fflush(stdout); // Must flush as it is bufferred and will not reach NS if not flushed in time
}

static void usage(char *error)
{
  ns_log_event("Critical", error);

  printf("Usage: ./ns_tcp_states_count { -l | -f comma separated include list } {-e comma separated exclude list } {-i interval#} {-t testrun#} {-p cavmon home path#} {-d debug#}");
  exit(1);
}

int main(int argc, char** argv)
{
  char c;
  char local[MAX_BUF_SIZE];
  char foreign[MAX_BUF_SIZE];
  char exclude[MAX_BUF_SIZE];
  int lflag = 0;
  int fflag = 0;
  int eflag = 0;
  int local_foreign_ip_port = 0;  // num of comma separated values given using option l/f
  int exclude_ip_port = 0;        // num of comma separated values given using option e

  while ((c = getopt(argc, argv, "i:t:p:P:dl:f:e:")) != -1)
  {
    switch (c)
    {
      case 'i':               
        interval = atoi(optarg);
        break;
      case 't':               
        test_run = atoi(optarg);
        break;
      case 'p':               
        strcpy(cav_mon_home, optarg);
        break;
      case 'P':
        partition_idx = atol(optarg);
        break;
      case 'd':               
        debug_level = 1;
        break;
      case 'l':
        lflag++;
        strcpy(local, optarg);
        break;
      case 'f':
        fflag++;
        strcpy(foreign, optarg);
        break;
      case 'e':
        eflag++;
        strcpy(exclude, optarg);
        break;
      case ':':
      case '?':                             

      usage("Invalid argument.");      
    }
  }

  if(debug_level)
    debug_log(debug_level, "TCP States count started for Linux 64 bit.");

  //e option cannot be used alone
  //we can use e option either with l of f only 
  if(eflag)
  {
    if((lflag == 0) && (fflag == 0))
    {
      usage("Exclude flag (e) cannot be specified without l or f option.");      
    }
  }
  
  //calling set_ip_port() for tokenizing and storing input into different arrays.
  if(lflag) {
    set_ip_port(local, local_and_foreign_ip_port, local_and_foreign_ip, local_and_foreign_port, &local_foreign_ip_port);
    if(eflag) {
      set_ip_port(exclude, exclude_ip_and_port, exclude_ip, exclude_port, &exclude_ip_port);
    }
  } else if(fflag) {
    set_ip_port(foreign, local_and_foreign_ip_port, local_and_foreign_ip, local_and_foreign_port, &local_foreign_ip_port);
   if(eflag) {
      set_ip_port(exclude, exclude_ip_and_port, exclude_ip, exclude_port, &exclude_ip_port);
    }
  } else if(eflag) {
    set_ip_port(exclude, exclude_ip_and_port, exclude_ip, exclude_port, &exclude_ip_port);
  }

  init_mon();

  while(1)
  {
    if(isTestOver(test_run) == 1)
    { 
      if(debug_level)
        debug_log(debug_level, "Test is over. TCP States count stopped for Linux 64 bit.");
      
      //Test is over. So exit with success status
      close_mon(0);
    }

    //Using con_count_arr for both IPV4 & IPV6 hence need to memset this on every interval   
    memset(con_count_arr, 0, sizeof(int)*127);

    //Read file /proc/net/tcp and print connection state count 
    if(ipv4_fptr != NULL)
      get_and_show_data(ipv4_fptr, lflag, fflag, eflag, local_foreign_ip_port, exclude_ip_port, STATE_OFFSET_IPv4, LOCAL_IP_PORT_OFFSET_IPv4, REMOTE_IP_PORT_OFFSET_IPv4);

    //Read file /proc/net/tcp6 and print connection state count 
    if(ipv6_fptr != NULL)
      get_and_show_data(ipv6_fptr, lflag, fflag, eflag, local_foreign_ip_port, exclude_ip_port, STATE_OFFSET_IPv6, LOCAL_IP_PORT_OFFSET_IPv6, REMOTE_IP_PORT_OFFSET_IPv6);

    show_data();

    sleep(interval);
  }

  return 0;
}
