#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <ctype.h>
//#include "nslb_sock.h"
#include "../../../libnscore/nslb_sock.h"
//#include "../../../libnscore/nslb_util.h"
//#//include "../../../hpdd/hpd_msg_com_con.h"



//#define GET_CLUSTER_TRAFFIC_STATS_VECTOR_NAME 3
//#define GET_CLUSTER_TRAFFIC_STATS_PROTOCOL 29 //opcode to get only protocol

#define HPD_CLUSTER_STATS_DATA 57
#define HPD_CLUSTER_STATS_VECTOR_NAME 58

#define SVR_NAME 2*1024 + 1
#define VCT_PREFIX 1024 + 1
#define MAX_LINE_LENGTH 4*1024 + 1

#define SET_MIN(a , b)\
        if ((b) < (a)) (a) = (b)

#define SET_MAX(a , b)\
        if ((b) > (a)) (a) = (b)

#define MAX_BUF_SIZE 64000 //1MB

#define MIN_INIT 0xFFFFFFFF 

#define LOG_LEVEL_1 0x000000FF
#define LOG_LEVEL_2 0x0000FF00
#define LOG_LEVEL_3 0x00FF0000
#define LOG_LEVEL_4 0xFF000000

#define SET_DEBUG_LOG(d_log) \
{ \
  if (d_log == 1) d_log = 0x000000FF; \
  else if(d_log == 2) d_log = 0x0000FFFF; \
  else if(d_log == 3) d_log = 0x00FFFFFF; \
  else if(d_log == 4) d_log = 0xFFFFFFFF; \
}

static int g_cluster_mode;
static char g_cluster_name[256];
static char g_master_ip[256];
static int  g_master_port;

#define   _LF_ __LINE__, (char *)__FUNCTION__

#define MSG_HDR \
  int opcode; \
  int size; \
  int child_id; \
  int future; \
  long partition_idx;\

typedef struct parent_child{
  /* Following HDR should be same in parent_child and hvm_sample_data msg */
  MSG_HDR

  int elapsed;
  int hvm_sample_data_size; /* Size of the hvm sample data struct which is send in the progress report */
} parent_child;

typedef struct HpdClusterTrafficStat
{
  unsigned int req_recieved;
  unsigned int req_processed;
  unsigned int req_successfull;
  unsigned int req_failures;
/* These are derived from sample counts/interval
  int req_recieved_per_sec;
  int req_processed_per_sec;
  int req_successfull_per_sec;
  int req_failures_per_sec;
*/
  unsigned int min_service_time;
  unsigned int max_service_time;
  unsigned int avg_service_time;
  unsigned long long tot_req_recieved; 
  unsigned long long tot_req_processed;
  unsigned long long tot_req_successful;
  unsigned long long tot_req_failures; 
} HpdTrffStat;

typedef struct VectorInfo 
{
  char *vector_name;
  HpdTrffStat hpdTrffStat;
  FILE **data_file_fp; // Array of fp. One per HPD process
} VctInfo;

static int debug_level = 0; //off
static FILE *debug_fp = NULL;

static int g_buffer_size = 0;
static char *g_buffer = NULL;
static char *vct_file_buf = NULL;
static char g_hpd_wdir[1024];
int opcode ;
int g_hpd_interval;
/*Open Log files*/
static void open_debug_log(int proc_id) 
{
  char debug_log_file[1024];
  char *ptr = NULL; 

  ptr = getenv("CAV_MON_TMP_DIR");

  if(ptr != NULL)
    sprintf(debug_log_file, "%s/cm_hpd_cluster_stats_%d.log", ptr, proc_id);
  else
    sprintf(debug_log_file, "/tmp/cm_hpd_cluster_stats_%d.log", proc_id);

  debug_fp = fopen(debug_log_file, "w");
  if(debug_fp == NULL && debug_level) 
  {
    fprintf(stderr, "Error: Unable to open file '%s' for creating debug log file for hpd hpd traffic monitor.\n", 
                     debug_log_file);
    exit(-1);
  }
}

static char *get_cur_date_time() {
  time_t    tloc;
  struct  tm *lt;
  static  char cur_date_time[100];

  (void)time(&tloc);
  if((lt = localtime(&tloc)) == (struct tm *)NULL)
    strcpy(cur_date_time, "Error|Error");
  else
    sprintf(cur_date_time, "%02d/%02d/%02d %02d:%02d:%02d",
                           lt->tm_mon + 1, lt->tm_mday, (1900 + lt->tm_year)%2000,
                           lt->tm_hour, lt->tm_min, lt->tm_sec);
  return(cur_date_time);
}

static void debug_log(int log_level, int line, char *fname, char *format, ...) {
  va_list ap;
  char buffer[MAX_BUF_SIZE + 1] = "\0";
  int amt_written = 0, amt_written1=0;

  if((debug_level & log_level) == 0) return;

  amt_written1 = sprintf(buffer, "\n%s|%d|%s|", get_cur_date_time(), line, fname);
  va_start(ap, format);
  amt_written = vsnprintf(buffer + amt_written1 , MAX_BUF_SIZE - amt_written1, format, ap);
  va_end(ap);
  buffer[MAX_BUF_SIZE] = 0;

  if(amt_written < 0) {
    amt_written = strlen(buffer) - amt_written1;
  }

  if(amt_written > (MAX_BUF_SIZE - amt_written1)) {
    amt_written = (MAX_BUF_SIZE - amt_written1);
  }

  if(debug_fp) {
    if((fwrite(buffer, amt_written1+amt_written, 1, debug_fp))<0) {
      fprintf(stderr, "%s\n", "Unable to write to debug for ns_tr069_cp_data_post_processing.c");
      exit (-1);
    }
  }  else {
     fprintf(stderr, "%s", buffer + amt_written1);
  }

  /* Log immediately in case of log_always*/
  if(log_level && debug_fp) fflush(debug_fp);
}

/*static int nslb_run_cmd_and_get_last_line (char *cmd, int length, char *out)
{
  FILE *app = NULL;
  char temp[length + 1];
 
  debug_log(LOG_LEVEL_1, _LF_, "Method Called, cmd = [%s], length = %d", cmd?cmd:NULL, length);

  app = popen(cmd, "r");

  if(app == NULL)
  {
    fprintf(stderr, "Error: Error in executing command = %s. Error = %s\n", cmd, strerror(errno));
    return -1;
  }

  while(fgets(temp, length, app))
  {
    strcpy(out, temp); // Out will have the last line of command output
  }

  char *ptr;
  if((ptr = index(out, '\n')) != NULL)
    *ptr = '\0';

  if(pclose(app) == -1)
  {
    fprintf(stderr, "Error: Error in pclose(), Ignored. Error = %s\n", strerror(errno));
  }

  return 0;
}*/

/*static int nslb_get_total_lines_in_file(char *file_name)
{
char line_count_cmd[4096];
char cmd_output[1024 + 1];
struct stat stat_buf;
int count = 0;

  debug_log(LOG_LEVEL_1, _LF_, "Method Called, file_name = %s", file_name);
  if (stat(file_name, &stat_buf))
  {
    return 0;
  }

  sprintf(line_count_cmd, "wc -l %s | awk '{print $1}'", file_name);
  nslb_run_cmd_and_get_last_line (line_count_cmd, 1024, cmd_output);
  sscanf(cmd_output, "%d", &count);

  return count;
}*/


/************************************************************************
 *
 * my_recv()
 * This function handles partial reads in recv() system call
 * recv() man page says,
 *
 *        "The receive calls normally return any data available, up to the requested
 *         amount, rather than waiting for receipt of the full amount requested."
 *
 * This method calls the recv() in a loop until all data is read from the socket.
 *
 ************************************************************************/
size_t my_recv(int sockfd, void *buf, size_t len, int flags)
{
  size_t ret = 0, count = 0;
  //void *ptr = buf;

  while(1)
  {
    ret = recv(sockfd, buf + count, len - count, flags); 
    if(ret <= 0) // Error in recv
      break;

    if(ret > (len - count)) // Some error occured, returned bytes should not be more than requested
      return -1;

    count += ret;
    if(count >= len) // read all the data upto len bytes as requested by the caller of this function
      break;
  }

  if(count == 0) // Error 
    return -1;

  return count;
}

/*
Purpose  : This method is to send and receive data from netstorm
Argument : None, uses g_buffer 
Return Value	: None
Note: This method can be called in a loop. Once the data is over, the
      size of the data (first 4 bytes) will be zero.
      Data is sent from netstorm
*/
static int get_data(int fd)
{
//int fd = -1;
  int rcv_amt;
  //struct sockaddr cliaddr;
  int size;
  
  /* Read 4 bytes first for size */
  if ((rcv_amt = my_recv (fd, &size, sizeof(int), 0)) <= 0) {
    fprintf(stderr, "Unable to get message size errno = %d, error: %s\n",
                     errno, strerror(errno));
    return -1;
  }

  //fprintf(stdout, "Got size = %d\n", size);

  if(size == 0) /* Data is over */
    return -2;
  
  if (g_buffer_size == 0) 
  {
    g_buffer = malloc(size + 1);
    g_buffer_size = size;
  }
  else if (size > g_buffer_size)
  {
    g_buffer = realloc(g_buffer, size + 1);
    g_buffer_size = size;
  }
  

  if ((rcv_amt = my_recv (fd, g_buffer, size, 0)) <= 0) {
    fprintf(stderr, "Unable to get message of size = %d, errno = %d, error: %s\n",
                     size, errno, strerror(errno));;
    //perror("unable to rccv client sock");
    return -1;
  }

  g_buffer[rcv_amt] = '\0';
  return 0;
}

static int nslb_get_hpd_server_port()
{
  char buf_port[16]="\0";
  char file_name[1024];
  FILE *fp;

  sprintf(file_name, "%s/.tmp/.HPDPort", g_hpd_wdir);
  
  fp = fopen(file_name, "r");
  if(fp == NULL)
   return -1;

  fgets(buf_port, 16 , fp);
  fclose(fp);
  return(atoi(buf_port));
}

static void get_cluster_ip_and_port(char *buf)
{
  char keyword[100];
  char mode[56];
  char name[512];
  char ip[512];
  char port[100];
  char tmp[512];
  int num;

  keyword[0] = '\0';

  #define USAGE_HPD_CLUSTER "Usages: HPD_CLUSTER <mode> <name> <Master IP> <PORT> \n" \
                 "\tMode - 0/1 (1 - to mark the current hpd master)\n"\
                 "\tMaster IP - IP of Master HPD. \n"\
                 "\tport - port of Master HPD.\n"\
 
  num = sscanf(buf, "%s %s %s %s %s %s", keyword, mode, name, ip, port, tmp);

  if(num < 5){
    fprintf(stderr, "There should be only one value after keyword %s", USAGE_HPD_CLUSTER);
    exit(-1);
  }

  g_cluster_mode = atoi(mode);
  strcpy(g_cluster_name, name);
  strcpy(g_master_ip, ip);
  g_master_port = atoi(port);
}

static inline void read_hpd_conf_keywords()
{
  char conf_file[512];
  FILE *fp;
  char line[2048+1];

  char kw[512] = "";
  char val1[512] = "";
  char val2[512] = "";
  char tmp[512] = "";
  char error[4096] ;
  sprintf(conf_file, "%s/conf/hpd.conf", g_hpd_wdir);
  fp = fopen(conf_file, "r");
  if(fp == NULL)
  {
     fprintf(stderr, "Error: Unable to read %s file.", conf_file);
     exit(-1);
  }

  while(fgets(line, 2048, fp))
  {
    if(line[0] == '#' || line[0] == '\n' || line[0] == 0)
      continue;

    //remove \n
    line[strlen(line) - 1] = 0;

    val1[0] = val2[0] = tmp[0] = error[0] = 0;

    sscanf(line, "%s %s %s %s", kw, val1, val2, tmp);

    if(!strncasecmp(line, "HPD_CLUSTER", strlen("HPD_CLUSTER")))
      get_cluster_ip_and_port(line);
  }
}


static int make_connection_to_hpd_parent()
{
  //int i, ret;
  int fd;
  int hpd_port;
  //parent_child get_traffic_summary_msg;
  //char buffer[MAX_MESSAGE_SIZE + 1];
  
  hpd_port = nslb_get_hpd_server_port();
  if(hpd_port == -1)
  {
    fprintf(stderr, "Unable to get HPD parent port\n");
    exit(-1);
  }

  // to get data online
  //TODO: AA what if HPD is runningon particular IP
  if ((fd = nslb_tcp_client("127.0.0.1", hpd_port)) < 0) {
    fprintf(stderr, "Check if HPD is running\n");
    exit(-1);
  }
  return fd;
}


static int load_vectors(int num_vct, char *vct_file_buf, VctInfo *vct_list)
{
  int vct_idx = 0, vct_name_len = 0;
  char *star_vct_ptr, *tmp_ptr;

  star_vct_ptr = tmp_ptr = NULL;

  debug_log(LOG_LEVEL_1, _LF_, "Method called, num_vct = %d, vct_file_buf = [%s]", 
                                num_vct, vct_file_buf?vct_file_buf:NULL);
 
  tmp_ptr = star_vct_ptr = vct_file_buf;

  while ((tmp_ptr = strpbrk(star_vct_ptr, "\r\n")) != NULL) 
  {
    debug_log(LOG_LEVEL_3, _LF_, "vct_idx = %d, star_vct_ptr = [%s]", vct_idx, star_vct_ptr?star_vct_ptr:NULL);

    vct_name_len = tmp_ptr - star_vct_ptr; 

    debug_log(LOG_LEVEL_3, _LF_, "vct_name_len = %d", vct_name_len);

    vct_list[vct_idx].vector_name = (char *)malloc(vct_name_len + 1);
    debug_log(LOG_LEVEL_3, _LF_, "vct_list[%d].vector_name = %p", vct_idx, vct_list[vct_idx].vector_name);
    if(vct_list[vct_idx].vector_name == NULL)
    {
      fprintf(stderr, "Error: memory allocation for vector list of len %d at index %d is failed. Out of memory.", 
                       (vct_name_len + 1), vct_idx);
      exit (-1);
    }

    strncpy(vct_list[vct_idx].vector_name, star_vct_ptr, vct_name_len);
    vct_list[vct_idx].vector_name[vct_name_len] = '\0';

    debug_log(LOG_LEVEL_3, _LF_, "vct_idx = %d, num_vct = %d, vct_list[%d].vector_name = [%s]", 
                                  vct_idx, num_vct, vct_idx, vct_list[vct_idx].vector_name);

    if(vct_idx > num_vct)
      return 0;

    /*Here we are dealing with dos and linux file format both.
      Since dos file end with \r\n and linux file end with \n so pointing tmp_ptr as requirment*/
    if(*tmp_ptr == '\r')
      tmp_ptr += 2;   //skip \r \n
    if(*tmp_ptr == '\n')
      tmp_ptr++;

    star_vct_ptr = tmp_ptr;
    debug_log(LOG_LEVEL_3, _LF_, "vct_idx = %d, tmp_ptr = [%s]", vct_idx, tmp_ptr); 

    vct_idx++;
  }

  return 0; 
}

static void show_data(int num_vectors, int num_hpd, VctInfo *vct_list, int freq, char *service_name, char *hpd_cluster_stat_files_dir)
{
  int ret;//i = 0;
  int fd;
  parent_child get_traffic_summary_msg;

  debug_log(LOG_LEVEL_1, _LF_, "Method Called, num_vectors = %d, num_hpd = %d, freq = %d",
                               num_vectors, num_hpd, freq);

  fd = make_connection_to_hpd_parent();
  while(1) 
  {
    get_traffic_summary_msg.opcode = opcode;
    get_traffic_summary_msg.size = sizeof(parent_child);
    if (send(fd, &get_traffic_summary_msg, sizeof(get_traffic_summary_msg), 0) <= 0) {
      fprintf(stderr, "Unable to send message to HPD errno = %d, error: %s\n", errno, strerror(errno));
      close(fd);
      exit(-1);
    }

    while(1)
    { 
      ret = get_data(fd);
      if (ret == -2)
        break;
      
      if(ret != 0)
      {
        fprintf(stderr, "Unable to fetch data from HPD\n");
        close(fd);
        exit(-1);
      }
      printf ("%s", g_buffer);
      fflush(stdout); // Must flush as it is bufferred and will not reach NS if not flushed in time
    }
    debug_log(LOG_LEVEL_2, _LF_, "Sleeping for %d sec", freq);

    sleep(freq);
  }
  //close(fd);

#if 0
  while(1)
  {
    ret = load_data(num_vectors, service_name, hpd_cluster_stat_files_dir, vct_list, num_hpd);
    if(ret == -1)
    {
      fprintf(stderr, "Error: Loading Data failed.");
    }

    for(i=0; i<num_vectors; i++)
    {
      debug_log(LOG_LEVEL_2, _LF_, "Data:-");

      printf("%u %u %u %u %3.3f %3.3f %3.3f %3.3f %3.3f %3.3f %3.3f %u %llu %llu %llu %llu\n",
              vct_list[i].hpdTrffStat.req_recieved, vct_list[i].hpdTrffStat.req_processed,
              vct_list[i].hpdTrffStat.req_successfull, vct_list[i].hpdTrffStat.req_failures,

              ((double )vct_list[i].hpdTrffStat.req_recieved)/(double )freq, 
              ((double )vct_list[i].hpdTrffStat.req_processed)/(double )freq,
              ((double )vct_list[i].hpdTrffStat.req_successfull)/(double )freq, 
              ((double )vct_list[i].hpdTrffStat.req_failures)/(double )freq,

              (vct_list[i].hpdTrffStat.req_processed != 0)?
              (double )vct_list[i].hpdTrffStat.avg_service_time/(double )(vct_list[i].hpdTrffStat.req_processed *1000):
              (double )0,
              ((vct_list[i].hpdTrffStat.min_service_time != MIN_INIT) && 
               (vct_list[i].hpdTrffStat.min_service_time != (unsigned int)(-1 * 1000)))?
              (((double )vct_list[i].hpdTrffStat.min_service_time)/(double )1000):(double)0,
              ((double )vct_list[i].hpdTrffStat.max_service_time)/(double )1000,
              vct_list[i].hpdTrffStat.req_processed,

              vct_list[i].hpdTrffStat.tot_req_recieved, vct_list[i].hpdTrffStat.tot_req_processed, 
              vct_list[i].hpdTrffStat.tot_req_successful, vct_list[i].hpdTrffStat.tot_req_failures);
      fflush(stdout);
    }
    
    reset_data(num_vectors, num_hpd, vct_list);

    debug_log(LOG_LEVEL_2, _LF_, "Sleeping for %d sec", freq);

    sleep(freq);
  }
#endif
}

static void get_vec_list()
{
  int fd;
  int ret;
  parent_child get_traffic_summary_msg;
  fd = make_connection_to_hpd_parent();
  get_traffic_summary_msg.opcode = HPD_CLUSTER_STATS_VECTOR_NAME;
  get_traffic_summary_msg.size = sizeof(parent_child);
  if (send(fd, &get_traffic_summary_msg, sizeof(get_traffic_summary_msg), 0) <= 0) {
    fprintf(stderr, "Unable to send message to HPD errno = %d, error: %s\n", errno, strerror(errno));
    close(fd);
    exit(-1);
  }

  while(1)
  { 
    ret = get_data(fd);
    if (ret == -2)
      break;
    
    if(ret != 0)
    {
      fprintf(stderr, "Unable to fetch data from HPD\n");
      close(fd);
      exit(-1);
    }
    //printf ("Vectors = >%s", g_buffer);
  }
  close(fd);
  vct_file_buf = g_buffer;
  //printf ("Vectors = >%s", vct_file_buf);
}

static int usage()
{
   fprintf(stderr, "Usage:\n");
   fprintf(stderr, "      cm_hpd_cluster_stats  -i <interval in secs> -s <service name or All (default)>  -v <vector prefix - optional> -D <debug_level>\n\n");
   fprintf(stderr, "Where options are:\n");
   fprintf(stderr, "      -i: interval in sec\n");
   fprintf(stderr, "      -v: vector prefix - optional\n");
   fprintf(stderr, "      -c: controller name - optional\n");
   fprintf(stderr, "      -D: debug level - optional\n");
   fprintf(stderr, "      -X: vector prefix/noprefix - optional\n");
   fprintf(stderr, "      -L: header/data\n");
  
   exit(-1);
}
static void ns_log_event(char *severity, char *event_msg)
{
  fprintf(stdout, "Event:1.0:%s|%s\n", severity, event_msg);
  fflush(stdout);
}
int ns_is_numeric(char *str)
{
  int i;
  for(i = 0; i < strlen(str); i++) {
    if(!isdigit(str[i])) return 0;
  }
  return 1;
}
void get_hpd_time_interval()
{
  char buff[MAX_LINE_LENGTH] = "\0";
  char file[2048];
  char keyword[1024] = "\0";
  char text1[1024] = "\0";
  char text2[1024] = "\0";
  char text3[1024] = "\0";
  char text4[1024] = "\0";
  char text5[1024] = "\0";
  int num;
  int g_is_enable_progress_report;
  FILE *fp_hpd_conf;
  sprintf(file,"%s/conf/hpd.conf", g_hpd_wdir);
  debug_log(LOG_LEVEL_2, _LF_, "Opening file %s to take hpd time interval", file);
  if ((fp_hpd_conf = fopen(file, "r")) == NULL)
  {
    fprintf(stderr, "Error: Unable to open the file %s.\n", file);
    exit(-1);
  }

  debug_log(LOG_LEVEL_2, _LF_, "File %s opened succefully. Now Reading the file line by line", file);
  while(fgets(buff, MAX_LINE_LENGTH, fp_hpd_conf) != NULL)
  {
    buff[strlen(buff) - 1] = '\0';  // Replace new line by Null
    if(strchr(buff, '#') || buff[0] == '\0')
      continue;
    num=sscanf(buff, "%s %s %s %s %s %s", keyword, text1, text2, text3, text4, text5);
    if (num < 2)
      continue; // we are continuing this because buff may have spaces
   
   if(strcmp(keyword, "PROGRESS_ENABLED") == 0)
   {
     if(num > 3)
    {
      //error_log(0, 0, _LF_, NULL, "Format of PROGRESS_REPORT keyword is not correct. %s", buff);
      //error_log(0, 0, _LF_, NULL, "Setting default values for PROGRSS_REPORT");
      return;
    }
    if(ns_is_numeric(text1))
    g_is_enable_progress_report = atoi(text1);

   if(g_is_enable_progress_report > 0 )
   {
    if (text2[0] != 0)
    {
      if(ns_is_numeric(text2))
      {
        g_hpd_interval = atoi(text2)/1000;
      }
    }
   }
  }
 }
fclose(fp_hpd_conf);
}

int main(int argc, char** argv)
{
  char hpd_cluster_stat_files_dir[VCT_PREFIX];
  char file_name[VCT_PREFIX];
  char service_name[SVR_NAME];
  char vector_prefix[VCT_PREFIX];
  char controller_name[SVR_NAME];
  char header_or_data[20] = "";
  char option[20] = "all";
  char line_buf[MAX_LINE_LENGTH];
  int interval = 10; 
  int mon_freq;
  int num_hpd = 0, num_vectors = 0;
  char *ptr = 0;
  FILE *fp;
  int vector_flag = 0;
  
  //struct stat stat_st;
  //int file_size = 0;
  //int read_fd = 0;
  //int read_bytes = 0;
 
  //read cluster regarding gdf
  //read_hpd_conf_keywords(); 
  int ret;
  char arg;
  pid_t pid;

  VctInfo *vct_list = NULL;

  file_name[0] = 0, service_name[0] = 0, vector_prefix[0] = 0, line_buf[0] = 0, controller_name[0] = 0;
 
  if(getenv("MON_FREQUENCY") != NULL)
    mon_freq = atoi(getenv("MON_FREQUENCY"));
  if(mon_freq > 0)
    interval = mon_freq / 1000;

  while((arg = getopt(argc, argv, "i:v:D:c:X:L:o:")) != -1)
  {
    switch(arg)
    {
      case 'i':
        interval = atoi(optarg); 
        break;

      case 'v':
        // Commenting below line as per Bug#13913 as we don't want to send prefix while sending data because we can not apply that prefix 
        // in hpd, and if we dont send prefix in hpd there will be a mismatch in service names.
        //strcpy(vector_prefix, optarg); 
        strcpy(vector_prefix, "noprefix"); 
        vector_flag = 1;
        break;

      case 'X':
        // Commenting below line as per Bug#13913 as we don't want to send prefix while sending data because we can not apply that prefix 
        // in hpd, and if we dont send prefix in hpd there will be a mismatch in service names.
        //strcpy(vector_prefix, optarg); 
        strcpy(vector_prefix, "noprefix"); 
        
        break;

      case 'L':
        strcpy(header_or_data, optarg); 
        break;
      case 'D':
        debug_level = atoi(optarg); 
        break;

      case 'c':
        strcpy(controller_name, optarg);
        break;

       case 'o':
        strcpy(option, optarg);
        break;

      case '?':
      default:
        usage();
    }
  }

  //if 'data' is passed with -L option, then make vector_prefix null because in this case we have send data not vector
  if(!strcasecmp(header_or_data, "data")) 
    vector_flag = 0;
  else if(!strcasecmp(header_or_data, "header"))
    vector_flag = 1;

   if( vector_flag == 0 )
   {
     opcode = HPD_CLUSTER_STATS_DATA;
   }
  /* Get process id*/
   if ((pid = getpid()) < 0) 
     fprintf(stderr,"Error: unable to get pid.\n");
   
  /* Opening debug file and setting debug mask*/
  if(debug_level)
  {
    open_debug_log(pid);
    SET_DEBUG_LOG(debug_level);
  }

  debug_log(LOG_LEVEL_1, _LF_, "Method Called, interval = %d, service_name = %s, vector_prefix = %s",
                                interval, service_name, vector_prefix);

  /* Set Directory  path where csv file made*/
  if(controller_name[0] != 0)
  {
    /*handle cases for work, work2, work3 */
    if(!strcmp(controller_name, "work"))
      strcpy(hpd_cluster_stat_files_dir, "/var/www/hpd/logs/hpd_cluster_stat");
    else if(!strcmp(controller_name, "work2"))
      strcpy(hpd_cluster_stat_files_dir, "/var/www2/hpd/logs/hpd_cluster_stat");
    else if(!strcmp(controller_name, "work3"))
      strcpy(hpd_cluster_stat_files_dir, "/var/www3/hpd/logs/hpd_cluster_stat");
    else {
      //home/netstorm/ControllerUAT/hpd/logs
      sprintf(hpd_cluster_stat_files_dir, "/home/netstorm/%s/hpd/logs/hpd_cluster_stat", controller_name); 
    }
  }
  else if((ptr = getenv ("HPD_ROOT")) != NULL)
  {
    sprintf(hpd_cluster_stat_files_dir, "%s/logs/hpd_cluster_stat", ptr);
  } 
  else //ptr == NULL
  {
    ptr = "/var/www/hpd";
    sprintf(hpd_cluster_stat_files_dir, "%s/logs/hpd_cluster_stat", ptr);
  }   

  char *tmp_ptr = strstr(hpd_cluster_stat_files_dir, "logs");
  if(tmp_ptr == NULL)
  {
    fprintf(stderr, "HPD Root is not set\n");
    exit(-1);
  }

  memset(g_hpd_wdir, 0, 1024);
  strncpy(g_hpd_wdir, hpd_cluster_stat_files_dir, (tmp_ptr - hpd_cluster_stat_files_dir));

  debug_log(LOG_LEVEL_2, _LF_, "Finding number of vectors, service_name = [%s]", *service_name?service_name:NULL);
  if(service_name[0] != 0)  //if service is given then only one vector will exist
  {
    num_vectors = 1;
  }
  if(vector_flag)
    get_vec_list();
  get_hpd_time_interval();

  if(vector_flag)
  {
//    show_vector(num_vectors, vct_list, service_name, vector_prefix);
//    show_vector(num_vectors, service_name, vector_prefix);
     printf("%s\n", vct_file_buf);
     fflush(stdout);
  }
  else
  {
    if( interval != g_hpd_interval )
    {
      //log event if time interval of hpd and monitor is not equal
      ns_log_event("Warning","Data which we are getting is of hpd time interval");
    }

    show_data(num_vectors, num_hpd, vct_list, interval, service_name, hpd_cluster_stat_files_dir);
  }
  return 0;  
}
