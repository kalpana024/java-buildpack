/*
 * Name   : cm_instance_and_port_check.c
 * Purpose: This will outputs 0/1 based on the listening status of the given input. 
 * Output : 0:Instnace|0    OR     0:Instance|1 
 * Author:  Abhishek/Anshul
 * Initial version: date: 2016/12/21 
 */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <ctype.h>
#include <math.h>
#include <time.h>

#define MAX_BUF_SIZE 1024
#define MAX_PORTS_IN_LISTEN 65536
#define STATE_OFFSET_IPv4 30
#define STATE_OFFSET_IPv6 78
#define LOCAL_IP_PORT_OFFSET_IPv4 2
#define LOCAL_IP_PORT_OFFSET_IPv6 26
#define REMOTE_IP_PORT_OFFSET_IPv4 16
#define REMOTE_IP_PORT_OFFSET_IPv6 64
#define MAX_IP_PORT_LENGTH  100


static int debug_level = 0;
typedef struct DATA
{
  char *instance;
  int data;
  int id;
  char ip_port_in_hex[MAX_IP_PORT_LENGTH];
}DATA;

DATA *data_arr;
int data_idx[MAX_PORTS_IN_LISTEN];

static FILE *ipv4_fptr = NULL; // WE need to open once, so make it static
static FILE *ipv6_fptr = NULL;
FILE *debug_fptr = NULL;

char *ipv4_file_name ="/proc/net/tcp";
char *ipv6_file_name ="/proc/net/tcp6";
char debug_file[1024];

//Initializing interval to -1 so that further we can set interval to MON_FREQUENCY by checking -1
int interval = -1;  
char cav_mon_home[MAX_BUF_SIZE] = {0};

int port_index = 1;


char *get_absolute_time() {
  time_t  tloc;
  struct  tm *lt;
  static  char cur_date_time[100]; 
    
  (void)time(&tloc); 
  if((lt = localtime(&tloc)) == (struct tm *)NULL)
    strcpy(cur_date_time, "Error");
  else
    sprintf(cur_date_time, "%02d/%02d/%02d %02d:%02d:%02d", lt->tm_mday, lt->tm_mon + 1, (1900 + lt->tm_year)%2000, lt->tm_hour, lt->tm_min, lt->tm_sec);
  return(cur_date_time);
}


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
    fprintf(debug_fptr, "%s|%s\n", get_absolute_time(), buffer);
  }
}

static void ns_log_event(char *severity, char *event_msg)
{
  fprintf(stdout, "Event:1.0:%s|%s\n", severity, event_msg);
  fflush(stdout);
}

static void usage(char *error)
{
  ns_log_event("Critical", error);

  printf("Usage: ./cm_instance_and_port_check { -p \"ip_1:port_1:instance_1,ip_2:port_2:instance_2,ip3:port_3..\" } OR {-p any}  AND optional arguements {-i interval} {-X prefix} {-L header/data} {-d (for debug)}\n-p is mandatory arguements\n\n");
  exit(1);
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
    fields[totalFlds - 1] = token_ptr;
  }
  return(totalFlds);
}


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
      ns_log_event("Critical", "Error in closing /proc/net/tcp file.");
    }
  } 
  if(debug_fptr)
  {
    if(fclose(debug_fptr) != 0)
    {
      ns_log_event("Critical", "Error in closing debug file.");
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
 *                           c.  Address of num_fields because we need no. of comma separated values for all the cases l/f/e for further executing for                                 loop in function get_data().
 * 
 * Output : Values in addressess passed to it.
 * */
static int set_ip_port(char *ip_port, char ip_in_hex[][MAX_IP_PORT_LENGTH], char port_in_hex[][MAX_IP_PORT_LENGTH], int *num_fields)
{
  char *comma_seperated_field[MAX_IP_PORT_LENGTH];
  char *colon_separated_field[MAX_IP_PORT_LENGTH];
  char *dot_separated_field[MAX_IP_PORT_LENGTH];

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
  memset(comma_seperated_field, 0, sizeof(comma_seperated_field));
  memset(dot_separated_field, 0, sizeof(dot_separated_field));

  //if comma found then tokenizing based on comma.
  if(strstr(ip_port, ","))
    *num_fields = get_tokens(ip_port, comma_seperated_field, ",", MAX_IP_PORT_LENGTH);
  else
  {
    //if comma not found then 0th index of comma_seperated_field will point to input ip address
    //this is done because further we are executing for loop of *num_fields.
    comma_seperated_field[0] = ip_port;
    *num_fields = 1;
  }

  //maximum 100 comma separated ip address can be given
  if(*num_fields > MAX_IP_PORT_LENGTH)
  {
    fprintf(stdout, "Error: Given comma separated values %d which is greater than maximum comma separated values 100.\n", *num_fields);
    close_mon(0);
  }

  data_arr = malloc(*num_fields * sizeof(DATA));
  if(data_arr == NULL)
  {
    ns_log_event("Critical", "Error: Can not malloc memory for data_arr");
    close_mon(-1);
  }
    
  //for loop of comma separated values.
  for(k = 0; k < *num_fields; k++)
  {
    //reset
    memset(buf_arry, 0, sizeof(buf_arry));
    memset(buf_port, 0, sizeof(buf_port));
    num_colon_separated_field = num_dot_separated_field = 0;

    //if colon found in any comma separated values then will tokenize it further into ip and port
    if(strstr(comma_seperated_field[k], ":"))
    {
      num_colon_separated_field = get_tokens(comma_seperated_field[k], colon_separated_field, ":", 3);

      if(num_colon_separated_field != 3)
      {
        ns_log_event("Critical", "Error: Wrong Input format of IP:PORT:INSTANCE");
        continue;
      }
     
      data_arr[k].instance = (char *)malloc(strlen(colon_separated_field[2]) + 1);
      if(data_arr[k].instance == NULL)
      {
        ns_log_event("Critical", "Error: Can not malloc memory for storing instance");
        close_mon(-1);
      }
      strcpy(data_arr[k].instance, colon_separated_field[2]);
      strcpy(server_ip, colon_separated_field[0]);
      port = atoi(colon_separated_field[1]);
     
    }
    else
    {
      if(strcasecmp(comma_seperated_field[k], "ANY") == 0)
      {
        data_arr = malloc(MAX_PORTS_IN_LISTEN * sizeof(DATA));
        if(data_arr == NULL)
        {
          ns_log_event("Critical", "Error: Can not malloc memory for data_arr");
          close_mon(-1);
        }
        return 1;
      }

      fprintf(stdout, "Error: Invalid format input passed in -p option. Arguement passed is %s\n", comma_seperated_field[k]);
      if(*num_fields == 1)
      {
        usage("Error: Invalid arguement passed");
      }
      else
        continue;
    }

    //further tokenizing ip by dot (.)
    if(strstr(server_ip, "."))
    {
      num_dot_separated_field = get_tokens(server_ip, dot_separated_field, ".", 4);
  
      if(num_dot_separated_field != 4)
      {
        ns_log_event("Critical", "Error: Wrong Input format of server ip");
        continue;
      }
  
      for(s = 0; s < num_dot_separated_field; s++)
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
    if((num_colon_separated_field + num_dot_separated_field) == 7)
      sprintf(data_arr[k].ip_port_in_hex, "%s%s%s%s:%s", buf_arry[3], buf_arry[2], buf_arry[1], buf_arry[0], buf_port);
    else
    {
      fprintf(stderr, "Error: Invalid format.\n");
      close_mon(0);
    }

    if(debug_level)
      debug_log(debug_level, "set_ip_port() data_arr[k].ip_port_in_hex[%d] = %s, ip_in_hex[%d] = %s, port_in_hex[%d] = %s", k, data_arr[k].ip_port_in_hex, k, ip_in_hex[k] , k, port_in_hex[k]);
  }
  return 0;
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


static void init_mon()
{
  int mon_freq = -1;
  char cav_mon_home[100] = "";

  /* On some client machine we do not have /proc/net/tcp6 hence removed below check and 
   * checking this ptr is NULL or not while calling get_data(). 
   * So that we can give data of file which is present.
  */
  ipv4_fptr = fopen(ipv4_file_name, "r"); 

  if ((ipv4_fptr == NULL)) {
    ns_log_event("Critical", "Error in opening /proc/net/tcp file. Monitor data will not be available");
  }
  
  ipv6_fptr = fopen(ipv6_file_name, "r");

  if ((ipv6_fptr == NULL)) {
    ns_log_event("Critical", "Error in opening /proc/net/tcp6 file. Monitor data will not be available");
  }
    if ((ipv4_fptr == NULL) && (ipv6_fptr == NULL)){
      close_mon(-1);
    }

  if(debug_level)
  {
    if(getenv("CAV_MON_HOME") != NULL)
    {
      strcpy(cav_mon_home, getenv("CAV_MON_HOME"));
      sprintf(debug_file, "%s/logs/cm_instance_and_port_check_debug.log", cav_mon_home);
     
      debug_fptr = fopen(debug_file, "a+"); 
      if ((debug_fptr == NULL)) 
      {
        ns_log_event("Critical", "Error in opening debug file debug. Continuing without debug.");
      }
    }
    else
      debug_level = 0;
  }

  // interval is not passed, set this to MON_FREQUENCY
  if(interval == -1)
  {
    if(getenv("MON_FREQUENCY") != NULL)
      mon_freq = atoi(getenv("MON_FREQUENCY"));
    if(mon_freq > 0)
      interval = mon_freq / 1000;

    if(interval < 1) // In case MON_FREQUENCY is not set or it is too low.
      interval = 10;
  }
}

int convert_port_to_int(char remainder)
{
  int c;
  switch(remainder)
  {
    case 'a':
    case 'A': return 10;
    case 'b':
    case 'B': return 11;
    case 'c':
    case 'C': return 12;
    case 'd':
    case 'D': return 13;
    case 'e': 
    case 'E': return 14;
    case 'f':
    case 'F': return 15;
    default : c = atoi(&remainder); return c;
  }
}

int convert_port_to_dec(char * port)
{
  
  int decimal_number = 0, remainder, count = 0, i;
  
  for(i=3; i>=0; i--)
  {  
    remainder = convert_port_to_int(port[i]);

    decimal_number = decimal_number + remainder * pow(16, count);
    count++;
  }
  return decimal_number;
}


int check_count_for_tcp6(int num_fields)
{ 
  int i, count = 0;
  for(i = 0; i < num_fields; i++)
  {
    if(data_arr[i].data == 0)
    {	
      data_idx[count] = i;
      count++;
    }
  }
  return count;
}


//Read file proc/net/tcp line by line and increment connection states counters according to the options(l/f/e/no option) given
//and print value of all the possible connection states
static int get_data(FILE *fptr, int num_fields, int state_offset,int local_ip_port_offset, int remote_ip_port_offset, int is_ip_addr_any)
{
  char data_buf[MAX_BUF_SIZE];
  char *data;
  char *state;
  char ip_port[MAX_IP_PORT_LENGTH];         //to temporarily store address read from file /proc/net/tcp in ip:port format
  char ip[20];              //to temporarily store ip read from file /proc/net/tcp
  char port[10];            //to temporarily store port read from file /proc/net/tcp 
  int idx = 0;              //for loop of num of comma separated values given using options l/f 
  int indx = 0;             //for loop of num of comma separated values given using options e
  int flag = 0;
  //char *ptr_to_colon = NULL;

  if(debug_level)
    debug_log(debug_level, "get_data() function called. debug_level = %d, ",
                           "state_offset = %d, local_ip_port_offset = %d, remote_ip_port_offset = %d", 
                            debug_level, state_offset, local_ip_port_offset, remote_ip_port_offset);

  if(fseek(fptr, 0, SEEK_SET) < 0)
  {
    ns_log_event("Critical", "Error in seeking /proc/net/tcp file. Monitor data will not be available");
    return -1;
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

    if(state_offset == STATE_OFFSET_IPv4)
    {
    save_ip_port(data + LOCAL_IP_PORT_OFFSET_IPv4, ip_port, ip, port);
    state = data + STATE_OFFSET_IPv4;
    }
    else if(state_offset == STATE_OFFSET_IPv6)
    {
      save_ip_port(data + LOCAL_IP_PORT_OFFSET_IPv6, ip_port, ip, port);
      state = data + STATE_OFFSET_IPv6;
    }

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
  
    if(!strncmp(state, "0A", 2))
    {
      if(is_ip_addr_any == 1)
      {
        int dec_port = convert_port_to_dec(port);
        if(data_arr[dec_port].id == 0)
        {
          data_arr[dec_port].id = port_index; 
          port_index ++;
        }
        data_arr[dec_port].data = 1;
      }
      else
      {
        for(idx = 0; idx < num_fields; idx++)
        {
          if(state = STATE_OFFSET_IPv4)
          {
            if((!strcmp(ip_port, data_arr[idx].ip_port_in_hex)))
            {
              data_arr[idx].data = 1;
            }
          }
          else if (state_offset = STATE_OFFSET_IPv6)
          {
           if((!strcmp(ip_port, data_arr[data_idx[idx]].ip_port_in_hex)))
            {
              data_arr[data_idx[idx]].data = 1;
              break;
            }
          }
        }
      }
    }
  } 
}


void show_data(int num_fields, int is_ip_addr_any, char *prefix)
{
  int i, port;
  if(is_ip_addr_any)
  {
    for(port = 0; port < MAX_PORTS_IN_LISTEN; port++)
    {
      if(data_arr[port].id != 0)
      {
        printf("%d:%s%d|%d\n", data_arr[port].id, prefix, port, data_arr[port].data);
        data_arr[port].data = 0;
      }
    }
    fflush(stdout);
    return;
  }

  for(i = 0; i < num_fields; i++)
  {
    if(data_arr[i].instance)
    {
      printf("%d:%s%s|%d\n", i, prefix, data_arr[i].instance, data_arr[i].data);
      data_arr[i].data = 0;
    }
  }
  fflush(stdout); // Must flush as it is bufferred and will not reach NS if not flushed in time
}


int main(int argc, char** argv)
{
  char c;
  char port_in_hex[MAX_IP_PORT_LENGTH][MAX_IP_PORT_LENGTH];
  char ip_in_hex[MAX_IP_PORT_LENGTH][MAX_IP_PORT_LENGTH];
  char *ip_port = NULL;
  char prefix[MAX_IP_PORT_LENGTH] = "";
  int is_ip_addr_any;
  int num_fields;
  int count_of_IPv6;
  int i, vector_flag = 0, arg_len = 0;

  while ((c = getopt(argc, argv, "i:dp:X:L:")) != -1)
  {
    switch (c)
    {
      case 'i':               
        interval = atoi(optarg);
        break;
      case 'd':               
        debug_level = 1;
        break;
      case 'p':
        arg_len = strlen(optarg);
        ip_port = malloc((arg_len + 1)* sizeof(char));
        if(ip_port == NULL)
        {
          ns_log_event("Critical", "Can not malloc memory to store ip and port");
          close_mon(-1);
        }
        strcpy(ip_port, optarg);
        strcat(ip_port, "\0");
        break;
      case 'X':
        strcpy(prefix, optarg);
        break;
      case 'L':
        if(!(strcasecmp(optarg, "header")))
          vector_flag = 1;
        break;
      case '*':
      case '?':                             

      usage("Invalid argument.");    
    }
  }

  if ((argc == 1) || (ip_port == NULL))
    usage("-p is mandatory arguement."); 

  init_mon();

  if(debug_level)
    debug_log(debug_level, "TCP States count started for Linux 64 bit.");

  if(vector_flag)
  {
    printf("Warning: No vectors.\n");
    exit(0);
  }

  is_ip_addr_any = set_ip_port(ip_port, ip_in_hex, port_in_hex, &num_fields);

  if(is_ip_addr_any)
    num_fields = MAX_PORTS_IN_LISTEN;

  while(1)
  {

    //memset(data_arr, 0, sizeof(int)*127);
    //Read file /proc/net/tcp and print connection state count 
    
    if(ipv4_fptr)
    {
      get_data(ipv4_fptr, num_fields, STATE_OFFSET_IPv4, LOCAL_IP_PORT_OFFSET_IPv4, REMOTE_IP_PORT_OFFSET_IPv4, is_ip_addr_any);
    }
   
   if(ipv6_fptr && (is_ip_addr_any || (count_of_IPv6 = check_count_for_tcp6(num_fields)) > 0 ))
   {
      get_data(ipv6_fptr, count_of_IPv6, STATE_OFFSET_IPv6, LOCAL_IP_PORT_OFFSET_IPv6, REMOTE_IP_PORT_OFFSET_IPv6, is_ip_addr_any);
   }

    show_data(num_fields, is_ip_addr_any, prefix);
    sleep(interval);

}

  return 0;
}
