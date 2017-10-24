/****************************************************************************
 * Name	     : nslb_sock.c 
 * Purpose   : This file contain all connection related functions 
 * Code Flow : 
 * Author(s) : Manish Kr. Mishra 
 * Date      : Fri Jun  7 20:14:11 IST 2013 
 * Copyright : Cavisson System 
 * Modification History :
 *     Purpose : Move sock.c functions, and add nslb_tcp_client_r() for thread 
 *     Author  : Abhishek Mittal
 *      Date   : 
 *****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>
#include <errno.h>
#include <netdb.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/types.h>        
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include "nslb_sock.h"
#define MAX_DATA_LINE_LENGTH 512

/*------------------------------------------------------------------- 
 * Purpose   : This function will split the host and and port parts 
 *             IP port format - 
 *               IPv4: host:port
 *               IPv6: [host]:port 
 *
 * Input     : svr   - host ip address (with or without port) 
 *             hport - buff to contain splited host port 
 *
 * Output    : 1) hostname part
 *             2) host port in hport   
 *
 * Note      : If there is port in provided host address then it will return NULL
 *-------------------------------------------------------------------*/
char *nslb_split_host_port(char *svr, int *hport)
{
  char *ptr, *port_start, *hstart=svr;
  int is_port=1;

  if((ptr = index (svr, ':')) && index (ptr+1, ':')) 
  {
    //becuase there are two colons, it seems like an IPV6 address
    if (svr[0] != '[') 
    is_port = 0;
  else
    hstart = svr+1;
  }

  if(is_port && (port_start = rindex(hstart, ':'))) 
  {
    *port_start = '\0';
    if (*(port_start-1) == ']') 
      *(port_start-1) = '\0';
    else
      *port_start = '\0';
      port_start++;
     *hport = atoi(port_start);
  } 
  else
    *hport = 0;

  return(hstart);
}

/*------------------------------------------------------------------- 
 * Purpose   : This function will socket address structure by given ip port 
 *
 * Input     : addr          - buffer to which has to be filled by provided host ip and port
 *             server_name   - host name (with or without port)
 *             default_port  - default_port 
 *
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_fill_sockaddr_ex(struct sockaddr_in6 *addr, char *server_name, int default_port, char *err_msg)
{
  char *hptr;
  char buf[NSLB_SOCK_IP_PORT_LEN];
  int server_port;
  struct hostent *remote_server_ent;
  struct sockaddr_in *sin;
  int family;


  strcpy(buf, server_name);
  memset((char *)addr, 0, sizeof(struct sockaddr_in6));

  hptr = nslb_split_host_port (buf, &server_port);
  if (!server_port)  
  {//use default port 80
    if (default_port < 0 ) 
    {
      sprintf(err_msg, "Error: in getting server socket address of server '%s' - server has no port and no default port is provided", server_name);
      return 0;
    }
    server_port = default_port;
  }

  /* Doing this as in case of domain name we dont know the family so else part will check the both.*/
  family = AF_INET;
  if((remote_server_ent = gethostbyname2(hptr, family)) == NULL ) 
  {  //IPV4 - address & domainname
    family = AF_INET6;
    if ((remote_server_ent = gethostbyname2(hptr, family)) == NULL ) 
    {
      sprintf(err_msg, "Error: gethostbyname2(): in getting server socket address of server '%s' - %s", hptr, hstrerror(h_errno));
      return 0;
    }
  }

  if (family == AF_INET) 
  {
    sin = (struct sockaddr_in *) addr;
    sin->sin_family = AF_INET;
    sin->sin_port = htons(server_port);;
    bcopy( (char *)remote_server_ent->h_addr, (char *)&(sin->sin_addr), remote_server_ent->h_length );
    return (sizeof(struct sockaddr_in));
  } 
 //else if (remote_server_ent->h_addrtype == AF_INET6) i
  else if (family == AF_INET6)
  {
    addr->sin6_family = AF_INET6;
    addr->sin6_port = htons(server_port);;
    bcopy( (char *)remote_server_ent->h_addr, (char *)&(addr->sin6_addr), remote_server_ent->h_length );
    return (sizeof(struct sockaddr_in6));
  } 
  else 
  {
    sprintf(err_msg, "Error: in getting server socket address of server '%s' - Unsupported protocol address family %d", hptr, (int)(remote_server_ent->h_addrtype));
    return 0;
  }

  return 0; //Error case. It should not come here
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     : 
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_nb_open_socket(int family, char *err_msg)
{
  socklen_t reuseOptLen;
  int reuseOpt;

  int sock_fd = -1;
  

  /* sock_fd = socket(family, SOCK_STREAM | SOCK_NONBLOCK, 0); 
   * Note - on FC9 SOCK_NONBLOCK is not supported so to make socket non - blocking we need to steps 
   *  1) Open a blocking socket
   *  2) By fctl() make it non - blocking
   */
  sock_fd = socket(family, SOCK_STREAM, 0); 
  if(sock_fd < 0)
  {
    sprintf(err_msg, "Error: socket() failed to open a socket. errno %d (%s).\n", errno, strerror(errno));
    return -1;
  } 
 
  reuseOptLen = sizeof(reuseOpt);
  reuseOpt = 1;

  /* This only applies to reusing an address that is bound to a socket which is now closed
   * and in the TIME_WAIT state. We cant bind twice to an address that is active 
   */
  if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, (void*)&reuseOpt, reuseOptLen) < 0) 
  {
    sprintf(err_msg, "Error: setsockopt() SO_REUSEADDR failed for socket %d, errno %d (%s).\n", sock_fd, errno, strerror(errno));
    return -1;  
  }

  /* Making above open socket non - blocking*/
  if(fcntl(sock_fd, F_SETFL, O_NONBLOCK) < 0) 
  {
    sprintf(err_msg, "Error: fcntl() in making connection non blocking for socket %d, errno %d (%s).\n", sock_fd, errno, strerror(errno));
    return -1;
  }
  
  return sock_fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_nb_connect(int sock_fd, char *server_ip, int server_port, int *con_state, char *err_msg)
{
  struct sockaddr_in6 server_addr; 
  int err_num = 0, err;
  socklen_t errlen;

  if(server_ip == NULL)
  {
    return -1;
  }

  if(nslb_fill_sockaddr_ex(&server_addr, server_ip, server_port, err_msg) < 0)
    return -1;
 
  //If connection doennot make by any reason then return their errno  
  if(connect(sock_fd, (struct sockaddr*)&(server_addr), sizeof(struct sockaddr_in6)) < 0)
  {
    sprintf(err_msg, "%s", "Error: connect(): ");

    err_num = errno; 
    switch(err_num)
    {
      case EISCONN: // Connecton is already made
        //TODO: is we need to remove connection on send time.
        *con_state = NSLB_CON_CONNECTED;
        break;
      case EINVAL: // Invalid arguments. Something wrong with socket
        errlen = sizeof(err);
        if(getsockopt(sock_fd, SOL_SOCKET, SO_ERROR, (void*) &err, &errlen ) < 0 )
          sprintf(err_msg, "%sunknown connect error.\n", err_msg);
        else
          sprintf(err_msg, "%serrno %d (%s).\n", err_msg, err, strerror(err));
        return -1;
      case EAGAIN:
      case EALREADY :
      case EINPROGRESS :
        *con_state = NSLB_CON_CONNECTING; 
        break;
      case ECONNREFUSED:
        sprintf(err_msg, "%s Connection refused for fd %d, errno %d (%s).\n", err_msg, sock_fd, err_num, strerror(err_num));
        return -1;
      default:
        sprintf(err_msg, "%serrno %d (%s).\n", err_msg, err_num, strerror(err_num));
        return -1;
    }
    return 1;
  }

  *con_state = NSLB_CON_CONNECTED;
  return 0;  //Connection made succfully
}
























/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 -1: socket error
 -2: Ip/port not free
 -3: rong IP
 *-------------------------------------------------------------------*/
int nslb_tcp_listen_ex(int local_port, int backlog, char *ip_addr, char* err_msg)
{
int lfd;
struct sockaddr_in  my_addr;
int                 one = 1;
struct in_addr in_addr;

    memset(&my_addr, 0, sizeof(my_addr));

    if ((lfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        sprintf(err_msg, "Error in creating socket. Error: %s\n", strerror(errno));
        //perror("tcp_listen:socket");
        //exit(1);
        return (-1);
    }
    if((setsockopt(lfd, SOL_SOCKET,SO_REUSEADDR,(char *)&one,sizeof(one))) == -1) {
        //perror("setsockopt(SO_REUSEADDR)");
        //printf("httpd: could not set socket option SO_REUSEADDR\n");
        sprintf(err_msg, "Error in setting socket options for reuse address. Error: %s", strerror(errno));
        return(-1);
    }

    my_addr.sin_family = AF_INET;
    my_addr.sin_port = htons(local_port);

    if(ip_addr == NULL)
      my_addr.sin_addr.s_addr = INADDR_ANY;
    else
    {
      if(inet_aton(ip_addr, &in_addr) == 0)
      {
        sprintf(err_msg, "Error: Invalid IP address (%s) given in tcp_listen_ex().", ip_addr);
        //fprintf(stderr, "Error: tcp_listen_ex() - Invalid IP address (%s)\n", ip_addr);
        return(-3);
      }
      my_addr.sin_addr.s_addr = (in_addr_t)in_addr.s_addr;
    }

    if (bind(lfd, (struct sockaddr *)&my_addr, sizeof(my_addr)) < 0) {
        //if(errno == EINVAL)
        if(errno == EADDRINUSE)
        {
          if(ip_addr)
            sprintf(err_msg, "Error in binding for listen socket (IP = %s, Port = %d). IP Address and port is in use", ip_addr, local_port);
          else 
            sprintf(err_msg, "Error in binding for listen socket (Port = %d). IP Address and port is in use", local_port);
        }
        else
        {
          if(ip_addr)
            sprintf(err_msg, "Error in binding for listen socket (IP = %s, Port = %d). Error = %s", ip_addr, local_port, strerror(errno));
	  else
            sprintf(err_msg, "Error in binding for listen socket (Port = %d). Error = %s", local_port, strerror(errno));
        }

        return(-2);
    }
#if 0
    my_inane = sizeof(my_addr);
    if (getsockname(lfd, (struct sockaddr *)&my_addr, &my_inane) < 0) {
        perror("Proxy server unable to getsockname() for client connection\n");
        exit(1);
    }
#endif
    /* make this socket listen for incoming data */
    if (listen(lfd, backlog) < 0) {
        //perror("Proxy server unable to listen on designated socket\n");
        sprintf(err_msg, "Error in listening on socket. Error: %s", strerror(errno));
        return(-1);
    }
    return lfd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 -1: socket error
 -2: Ip/port not free
 -3: rong IP
 *-------------------------------------------------------------------*/
int nslb_tcp_listen(int local_port, int backlog, char* err_msg)
{
  return(nslb_tcp_listen_ex(local_port, backlog, NULL, err_msg));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 -1: socket error
 -2: Ip/port not free
 -3: rong IP
 *-------------------------------------------------------------------*/
inline int nslb_Tcp_listen_ex(int local_port, int backlog, char *ip_addr, char* err_msg)
{
  return(nslb_tcp_listen_ex(local_port, backlog, ip_addr, err_msg));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 -1: socket error
 -2: Ip/port not free
 -3: rong IP
 *-------------------------------------------------------------------*/
inline int nslb_Tcp_listen(int local_port, int backlog, char* err_msg)
{
  return(nslb_tcp_listen_ex(local_port, backlog, NULL, err_msg));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 *-------------------------------------------------------------------*/
int nslb_tcp_listen6(int local_port, int backlog)
{
int lfd;
struct sockaddr_in6  my_addr;
int                 one = 1;

    memset(&my_addr, 0, sizeof(my_addr));

    if ((lfd = socket(AF_INET6, SOCK_STREAM, 0)) < 0) {
        perror("tcp_listen:socket");
        exit(1);
    }
    if((setsockopt(lfd, SOL_SOCKET,SO_REUSEADDR,(char *)&one,sizeof(one))) == -1) {
        perror("setsockopt(SO_REUSEADDR)");
        printf("httpd: could not set socket option SO_REUSEADDR\n");
        exit(1);
    }
    my_addr.sin6_family = AF_INET6;
    my_addr.sin6_port = htons(local_port);
    my_addr.sin6_addr = in6addr_any;

    if (bind(lfd, (struct sockaddr *)&my_addr, sizeof(my_addr)) < 0) {
        perror("tcp_listen6 unable to create socket for client connection.\n");
        fprintf(stderr, "Most likely the port '%d' is not free -- \n", local_port);
        exit(1);
    }
#if 0
    my_inane = sizeof(my_addr);
    if (getsockname(lfd, (struct sockaddr *)&my_addr, &my_inane) < 0) {
        perror("Proxy server unable to getsockname() for client connection\n");
        exit(1);
    }
#endif
    /* make this socket listen for incoming data */
    if (listen(lfd, backlog) < 0) {
        perror("tcp_listen6 unable to listen on designated socket\n");
        exit(1);
    }
    return lfd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 Return Values: 
 Listen fd at Success
 *-------------------------------------------------------------------*/
inline int nslb_Tcp_listen6(int local_port, int backlog)
{
int fd;
	
	fd = nslb_tcp_listen6(local_port, backlog);
	if (fd < 0) {
	    printf("tcp listen6 failed for port=%d and backlog=%d\n", local_port, backlog);
	    exit(1);
	}
	return  fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
inline void nslb_Fcntl (int fd, int cmd, long arg)   //SS: function not used
{ 
    	if ( fcntl( fd, cmd, arg ) < 0 ) {
	    perror("fcntl failed");
	    close(fd);
	    exit(1);
	}
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
  One who needs err_msg need to call ns_fill_sockaddr_ex
 *-------------------------------------------------------------------*/
int nslb_fill_sockaddr(struct sockaddr_in6 * saddr, char *server_name, int default_port)
{
   char err_msg[1024]="\0";
   int ret ;
   if((ret = nslb_fill_sockaddr_ex(saddr, server_name, default_port, err_msg)) == 0)
     fprintf(stderr, "%s\n", err_msg);

   return ret;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_tcp_client_ex(char *server_name, int default_port, int timeout_val, char *err_msg)
{
int fd;
//char *ptr;
//char buf[256];
//int server_port;
struct sockaddr_in6  remote_server_addr;
//struct hostent     *remote_server_ent;
	//strcpy(buf, server_name);

        //memset(&remote_server_addr, 0, sizeof(remote_server_addr));
        if ((fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
           sprintf(err_msg, "socket (TCP) err : %s", strerror(errno));
           return -1;
        }

#if 0
	ptr = index(buf, ':'); //Check if port is provided
	if (ptr)  {
	    *ptr = '\0';
	    server_port = atoi(ptr+1);
	} else { //use default port 80
	    if (default_port < 0 ) {
		fprintf(stderr, "tcp_client:server (%s) has no port and no default portprovided\n", server_name);
		close(fd);
        	return (-1);
	    }
	    server_port = default_port;
	}

    	if ((remote_server_ent = gethostbyname(buf)) == NULL ) {
        	perror("tcp_client:gethostbyname");
		fprintf(stderr, "host is %s\n", buf);
		close(fd);
        	return (-1);
    	 }

    	 bcopy( (char *)  remote_server_ent->h_addr,
         	(char *) &remote_server_addr.sin_addr,
               	remote_server_ent->h_length );
    	 remote_server_addr.sin_family = remote_server_ent->h_addrtype;
    	 remote_server_addr.sin_port = htons(server_port);
#endif
        if (!nslb_fill_sockaddr_ex(&remote_server_addr, server_name, default_port, err_msg)) {
	    close(fd);
            return (-1);
    	}

        if(timeout_val > 0)
        {
            struct timeval tv;
            memset(&tv, 0, sizeof(struct timeval));
            int ret = 0;
 
            tv.tv_sec = timeout_val;  /* timeout_val Secs Timeout */
            /*
            SO_SNDTIMEO:
              Sets the timeout value specifying the amount of time that an output function blocks because flow control prevents data from being sent. If a send operation has blocked for this time, it shall return with a partial count or with errno set to [EAGAIN] or [EWOULDBLOCK] if no data is sent. The default for this option is zero, which indicates that a send operation shall not time out. This option stores a timeval structure. Note that not all implementations allow this option to be set.
            */
            // fprintf(stderr,"Before setting send timeout\n");
            ret = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
            // fprintf(stderr,"Before setting send timeout\n");
            if(ret < 0)
            {
                fprintf(stderr, "Error in setting socket send timeout using setsockopt, Ignored. Error = %s", strerror(errno));
            }
         
            /*
            SO_RCVTIMEO:
              Sets the timeout value that specifies the maximum amount of time an input function waits until it completes. It accepts a timeval structure with the number of seconds and microseconds specifying the limit on how long to wait for an input operation to complete. If a receive operation has blocked for this much time without receiving additional data, it shall return with a partial count or errno set to [EAGAIN] or [EWOULDBLOCK] if no data is received. The default for this option is zero, which indicates that a receive operation shall not time out. This option takes a timeval structure. Note that not all implementations allow this option to be set.
            */
            // fprintf(stderr,"Before setting recv timeout\n");
            ret = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
            // fprintf(stderr,"Before setting recv timeout\n");
            if(ret < 0)
            {
                fprintf(stderr, "Error in setting socket recieve timeout using setsockopt, Ignored. Error = %s", strerror(errno));

            }
        }

	//printf("Connecting to %s (%d)\n", server_name, default_port);
        if ((connect(fd, (struct sockaddr *)&remote_server_addr, sizeof(remote_server_addr))) < 0 ) 
        {
          // fprintf(stderr, "connect error ...........\n");
          //perror("connect: ");
          sprintf(err_msg, "tcp_client(): Error in making connection to server %s. Error = %s", server_name, strerror(errno));
	  close(fd);
          return (-1);
        }
	return fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
   One who needs err_msg need to call tcp_client_ex
 *-------------------------------------------------------------------*/
int nslb_tcp_client(char *server_name, int default_port)
{
  char err_msg[1024]="\0";
  int ret;
  
  if((ret = nslb_tcp_client_ex(server_name, default_port, -1, err_msg)) < 0)
    fprintf(stderr, "%s", err_msg);

  return(ret);
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_udp_server (unsigned short port, int no_delay, char *ip_addr) {
  struct sockaddr_in udp_servaddr;
  int fd;
  int opt = 1;

  if ((fd = socket(PF_INET, SOCK_DGRAM, 0)) < 0) {
    perror("socket: ");
    return -1;
  }

  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(int)) < 0) {
    perror("setsockopt (REUSEADDR): ");
    close(fd);
    return -1;
  }

  memset(&udp_servaddr, 0, sizeof(udp_servaddr));

  if(ip_addr == NULL) {
     udp_servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
  } else {
#if 0
     if(inet_aton(ip_addr, &in_addr) == 0) {
       fprintf(stderr, "Error: tcp_listen_ex() - Invalid IP address (%s)\n", ip_addr);
       exit(-1);
     }
     //udp_servaddr.sin_addr.s_addr = htonl((in_addr_t)in_addr.s_addr);
     udp_servaddr.sin_addr.s_addr = (in_addr_t)in_addr.s_addr;
#endif 
     struct hostent *remote_server_ent;
     if ((remote_server_ent = gethostbyname2(ip_addr, PF_INET)) == NULL ) {
        perror("udp_server: gethostbyname");
        //sprintf(err_msg, "%s\nhost is %s err:%s", err_msg, hptr, hstrerror(h_errno));
        exit(-1); 
     }
     bcopy( (char *)remote_server_ent->h_addr, (char *)&(udp_servaddr.sin_addr.s_addr), remote_server_ent->h_length );
  }

  udp_servaddr.sin_family = AF_INET;
  udp_servaddr.sin_port = htons(port);

  if (bind(fd, (struct sockaddr *) &udp_servaddr, sizeof(udp_servaddr)) < 0)  {
    perror("bind:");
    close(fd);
    return -1;
  }

  if (no_delay) {
    if ( fcntl(fd, F_SETFL, O_NDELAY ) < 0 ) {
    	fprintf(stderr, "Setting fd to no-delay failed\n");
    	perror("fcntl (NODELAY): ");
    	(void) close(fd);
    	return -1;
    }
  }
  return fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_udp_server6(unsigned short port, int no_delay, char *ip_addr) {
  struct sockaddr_in6 udp_servaddr;
  int fd;
  int opt = 1;

  if ((fd = socket(AF_INET6, SOCK_DGRAM, 0)) < 0) {
    perror("socket: ");
    return -1;
  }

  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(int)) < 0) {
    perror("setsockopt (REUSEADDR): ");
    close(fd);
    return -1;
  }

  memset(&udp_servaddr, 0, sizeof(udp_servaddr));

  udp_servaddr.sin6_addr = in6addr_any; 
  udp_servaddr.sin6_family = AF_INET6;
  udp_servaddr.sin6_port = htons(port);

  if (bind(fd, (struct sockaddr *) &udp_servaddr, sizeof(udp_servaddr)) < 0)  {
    perror("bind:");
    close(fd);
    return -1;
  }

  if (no_delay) {
    if ( fcntl(fd, F_SETFL, O_NDELAY ) < 0 ) {
    	fprintf(stderr, "Setting fd to no-delay failed\n");
    	perror("fcntl (NODELAY): ");
    	(void) close(fd);
    	return -1;
    }
  }
  return fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_udp_client(char *server_name, int default_port, int no_delay)
{
int fd;
//char *ptr;
//char buf[256];
//int server_port;
struct sockaddr_in6  remote_server_addr;
//struct hostent     *remote_server_ent;

        //memset(&remote_server_addr, 0, sizeof(remote_server_addr));
        if ((fd = socket(PF_INET, SOCK_DGRAM, 0)) < 0)  {
      	    perror("socket(UDP): ");
      	    return -1;
        }

 	if (no_delay)
	  if ( fcntl(fd, F_SETFL, O_NDELAY ) < 0 ) {
	  	perror("fcntl(NODELAY) :");
		close(fd);
	  	return(-1);
	  }

#if 0
	strcpy(buf, server_name);
	ptr = index(buf, ':'); //Check if port is provided
	if (ptr)  {
	    *ptr = '\0';
	    server_port = atoi(ptr+1);
	} else { 
	    server_port = default_port;
	}

	//CHK: Is it need to be gethostbyname or inet_addr?
    	if ((remote_server_ent = gethostbyname(buf)) == NULL ) {
        	perror("gethostbyname: ");
		fprintf(stderr, "host is %s\n", buf);
	 	close (fd);
        	return(-1);
    	 }

    	 bcopy( (char *)  remote_server_ent->h_addr,
         	(char *) &remote_server_addr.sin_addr,
               	remote_server_ent->h_length );
    	 remote_server_addr.sin_family = remote_server_ent->h_addrtype;
    	 remote_server_addr.sin_port = htons(server_port);
#endif

    	if (!nslb_fill_sockaddr(&remote_server_addr, server_name, default_port)) {
		close(fd);
        	return (-1);
    	 }

    /* Now get connected to the TCP server */
    if (connect(fd, (struct sockaddr *) &remote_server_addr, sizeof(remote_server_addr)) < 0)  
    {
      //perror("connect:  ");
      fprintf(stderr, "Error: udp_client(): Connection refused from server %s\n", server_name);
      close(fd);
      return(-1);
    }
    return fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
  This function is a copy of sock_ntop; but it does not append string like IPv4, IPv6 & give port if u want
 *-------------------------------------------------------------------*/
char *nslb_sockaddr_to_ip(const struct sockaddr *sa, int give_port)
{
  static char str[128];		/* Unix domain is largest */
  char portstr[7];
  char *ptr;
  str[0] = '\0';

  ptr = str;

  switch (sa->sa_family) {
    case AF_INET: {
      struct sockaddr_in *sin = (struct sockaddr_in *) sa;

      if (inet_ntop(AF_INET, &sin->sin_addr, ptr, sizeof(str)-5) == NULL) {
    	strcat(str, "BadIP");
 	return(str);
      }

      if (ntohs(sin->sin_port) != 0 && give_port) {
 	snprintf(portstr, sizeof(portstr), ":%d", ntohs(sin->sin_port));
	strcat(str, portstr);
      }
      return(str);
    }

    case AF_INET6: {
      struct sockaddr_in6	*sin6 = (struct sockaddr_in6 *) sa;
      if (inet_ntop(AF_INET6, &sin6->sin6_addr, ptr, sizeof(str)-5) == NULL) {
 	strcat(str, "BadIP");
	return(str);
      }
      if (ntohs(sin6->sin6_port) != 0 && give_port) {
	snprintf(portstr, sizeof(portstr), ":%d", ntohs(sin6->sin6_port));
	strcat(str, portstr);
      }
      return(str);
      }
    default:
      // Commented as in case of RBU, we do not make any connection
      // printf("sock_ntop: unknown AF_xxx: %d", sa->sa_family);
      strcat(str, "Bad Family or Address not used");
      return str;
  }
  strcat(str, "Bad Family");
  return str;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
char *nslb_sock_ntop(const struct sockaddr *sa)
{
    char		portstr[7];
    static char str[128];		/* Unix domain is largest */
    char *ptr;

	ptr = str;

	switch (sa->sa_family) {
	case AF_INET: {
		struct sockaddr_in	*sin = (struct sockaddr_in *) sa;

		strcpy (str, "IPV4:");
		ptr = str + strlen(str);
		if (inet_ntop(AF_INET, &sin->sin_addr, ptr, sizeof(str)-5) == NULL) {
			strcat(str, "BadIP");
			return(str);
		}
		if (ntohs(sin->sin_port) != 0) {
			snprintf(portstr, sizeof(portstr), ".%d", ntohs(sin->sin_port));
			strcat(str, portstr);
		}
		return(str);
	}
/* end sock_ntop */

	case AF_INET6: {
		struct sockaddr_in6	*sin6 = (struct sockaddr_in6 *) sa;

		strcpy (str, "IPV6:");
		ptr = str + strlen(str);
		if (inet_ntop(AF_INET6, &sin6->sin6_addr, ptr, sizeof(str)-5) == NULL) {
			strcat(str, "BadIP");
			return(str);
		}
		//printf ("IP from ntop is %s d[4]=%d\n", str, htonl(sin6->sin6_addr.in6_u.u6_addr32[3]));
		if (ntohs(sin6->sin6_port) != 0) {
			snprintf(portstr, sizeof(portstr), ".%d", ntohs(sin6->sin6_port));
			strcat(str, portstr);
		}
		return(str);
	}
#if 0
#ifdef	AF_UNIX
	case AF_UNIX: {
		struct sockaddr_un	*unp = (struct sockaddr_un *) sa;

			/* OK to have no pathname bound to the socket: happens on
			   every connect() unless client calls bind() first. */
		if (unp->sun_path[0] == 0)
			strcpy(str, "(no pathname bound)");
		else
			snprintf(str, sizeof(str), "%s", unp->sun_path);
		return(str);
	}
#endif

#ifdef	HAVE_SOCKADDR_DL_STRUCT
	case AF_LINK: {
		struct sockaddr_dl	*sdl = (struct sockaddr_dl *) sa;

		if (sdl->sdl_nlen > 0)
			snprintf(str, sizeof(str), "%*s",
					 sdl->sdl_nlen, &sdl->sdl_data[0]);
		else
			snprintf(str, sizeof(str), "AF_LINK, index=%d", sdl->sdl_index);
		return(str);
	}
#endif
#endif
	default:
                // Commented as in case of RBU, we do not make any connection
		// printf("sock_ntop: unknown AF_xxx: %d", sa->sa_family);
		return(NULL);
	}
    return (NULL);
}


/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
    Input saddr may be ipv4 or IPv6 network byte order address
    returns 4byte IPV4 address or last 4 byte IPv^ address in host byte order
    return s o on error
    For IPV6 tests,we use only last 32 bit as significant IPV6 address, rest part is fixed
    Fixed part can be configured using a global keyword
 *-------------------------------------------------------------------*/
unsigned int nslb_get_sigfig_addr (struct sockaddr_in6 *saddr)
{
unsigned int ipa;

	switch (saddr->sin6_family) {
	    case AF_INET: {
		struct sockaddr_in	*sin = (struct sockaddr_in *) saddr;
		return (ntohl(sin->sin_addr.s_addr));
	    }
	    case AF_INET6: {
		memcpy ((char *)&ipa, &(saddr->sin6_addr.s6_addr[12]), 4);
		return (ntohl(ipa));
	    }
	    default: {
                // Commented as in case of RBU, we do not make any connection
		// printf("ns_get_sigfig_addr: unknown AF_xxx: %d", saddr->sin6_family);
		return(0);
	    }

	}
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
char* nslb_get_src_addr(int fd)
{
  struct sockaddr_in6  sock_addr;
  int len;
  len = sizeof(sock_addr);
  if (getsockname(fd, (struct sockaddr *)&sock_addr, (socklen_t *)&len) < 0)
  {
    //perror("get_src_addr() - Error in getsockname()\n");
    //exit(-1);
    return "Unknown or Not Connected";
  }
  return (nslb_sock_ntop((struct sockaddr *)&sock_addr));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
    This is a copy of get_src_addr  but some control u need port or not
    (& also prefix is not added like IPV4/IPV6)
 *-------------------------------------------------------------------*/
char* nslb_get_src_addr_ex(int fd, int give_port)
{
  struct sockaddr_in6  sock_addr;
  int len;
  len = sizeof(sock_addr);
  if (getsockname(fd, (struct sockaddr *)&sock_addr, (socklen_t *)&len) < 0)
  {
    //perror("get_src_addr() - Error in getsockname()\n");
    //exit(-1);
    return "Unknown or Not Connected";
  }
  return (nslb_sockaddr_to_ip((struct sockaddr *)&sock_addr, give_port));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
    This must be used on connected FDs only.
 *-------------------------------------------------------------------*/
char* nslb_get_dest_addr(int fd)
{
  struct sockaddr_in6  sock_addr;
  int len;
  len = sizeof(sock_addr);
  if (getpeername(fd, (struct sockaddr *)&sock_addr, (socklen_t *)&len) < 0)
  {
    //perror("get_dest_addr() - Error in getpeername()\n");
    //exit(-1);
    return "Unknown or Not Connected";
  }
  return (nslb_sock_ntop((struct sockaddr *)&sock_addr));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
    This is a copy of get_dest_addr() but some control over wether we need port or not
    (& also prefix is not added like IPV4/IPV6)
 *-------------------------------------------------------------------*/
char* nslb_get_dest_addr_ex(int fd, int give_port)
{
  struct sockaddr_in6  sock_addr;
  int len;
  len = sizeof(sock_addr);
  if (getpeername(fd, (struct sockaddr *)&sock_addr, (socklen_t *)&len) < 0)
  {
    //perror("get_dest_addr() - Error in getpeername()\n");
    //exit(-1);
    return "Unknown or Not Connected";
  }
  return (nslb_sockaddr_to_ip((struct sockaddr *)&sock_addr, give_port));
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
    This function will provide tcp information 
 *-------------------------------------------------------------------*/
char *nslb_get_tcpinfo(int fd)
{
  static char tcp_info[1024];
  struct tcp_info tcpInfo; 

  socklen_t tcp_info_length;
  
  #if defined(linux) || defined(__FreeBSD__)
    //socklen_t     tcp_info_length;
    //struct iperf_stream *sp = test->streams;
    tcp_info_length = sizeof(struct tcp_info);

    //printf("Getting TCP_INFO for socket %d \n", sp->socket);
    //printf("Getting TCP_INFO for socket %d \n", fd);

    //if (getsockopt(sp->socket, IPPROTO_TCP, TCP_INFO, (void *)&rp->tcpInfo, &tcp_info_length) < 0) 
    if (getsockopt(fd, IPPROTO_TCP, TCP_INFO, (void *)&tcpInfo, &tcp_info_length) < 0) 
    {
      //perror("getsockopt");
    }

    #if defined(linux)
      sprintf(tcp_info, "tcpi_snd_cwnd = [%d], tcpi_snd_ssthresh = [%d], tcpi_rcv_ssthresh = [%d], tcpi_unacked = [%d]"
                        "tcpi_sacked = [%d], tcpi_lost = [%d], tcpi_retrans = [%d], tcpi_fackets = [%d], "
                        "tcpi_rtt = [%d], tcpi_reordering = [%d], tcpi_state = [%d])",
                        tcpInfo.tcpi_snd_cwnd, tcpInfo.tcpi_snd_ssthresh, tcpInfo.tcpi_rcv_ssthresh, tcpInfo.tcpi_unacked, 
                        tcpInfo.tcpi_sacked, tcpInfo.tcpi_lost, tcpInfo.tcpi_retrans, tcpInfo.tcpi_fackets,
                        tcpInfo.tcpi_rtt, tcpInfo.tcpi_reordering, tcpInfo.tcpi_state);
    #endif

    #if defined(__FreeBSD__)
      sprintf(tcp_info, "tcpi_snd_cwnd = [%d], tcpi_rcv_space = [%d], tcpi_snd_ssthresh = [%d], tcpi_rtt = [%d]",
                        tcpInfo.tcpi_snd_cwnd, tcpInfo.tcpi_rcv_space, tcpInfo.tcpi_snd_ssthresh, tcpInfo.tcpi_rtt);
    #endif

    //For debugging 
      //printf("###############################\n");
      //printf("TCP info - [%s]\n", tcp_info);
    return tcp_info;
  #else
    return "NOT Linux or __FreeBSD__";
  #endif
}


/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
   This functions fills in the saddr strutcure for IPV4 or IPV6 structure
   Returns the size of sockaddr_in for IPV4 or sockaddr_in6 for IPV6 or 0 on failure
   In size is always assumed to be sockaddr_in6.
    Return:
      > 0 - Address
      = 0 - Error and err_msg is filled with error message
 *-------------------------------------------------------------------*/
int nslb_fill_sockaddr_ex_r(struct sockaddr_in6 * saddr, char *server_name, int default_port, char *err_msg)
{
  char *hptr;
  char buf[MAX_DATA_LINE_LENGTH];
  int server_port;
  struct hostent *remote_server_ent;
  struct sockaddr_in *sin;
  int family;
  int server_name_len = strlen(server_name);

  if(server_name_len && server_name_len < MAX_DATA_LINE_LENGTH){
    //strcpy(buf, server_name);
    memcpy(buf, server_name, server_name_len);
    buf[server_name_len] = '\0';
  }
  else {
    sprintf(err_msg, "Error: length of server_name '%s' is more then '%d' or 0", server_name, MAX_DATA_LINE_LENGTH);
    return (0);

  }

  memset((char *)saddr, 0, sizeof(struct sockaddr_in6));

  hptr = nslb_split_host_port (buf, &server_port);
  if (!server_port)  {//use default port 80
    if (default_port < 0 ) {
      sprintf(err_msg, "Error in getting server socket address of server '%s' - server has no port and no default port is provided", server_name);
      return (0);
    }
    server_port = default_port;
  }

  /* Doing this as in case of domain name we dont know the family so else part will check the both.*/
  family = AF_INET;
  char tmp[1024];
  int tmplen = 1024;
  struct hostent hostbuf;
  int herr, hres;

  
  /* In gethostbyname2_r() we have to pass a buffer and this API fills this
   * buffer and point to result, and if buffer have less size from result its return ERANGE
   * So, we need to malloc the buffer and if get ERANGE, realloc the buffer
   * But in malloc and realloc process performance get effact.
   * For ignor this if we take a static buffer witih size 1024, and return an error, if get ERANGE*/

  /* if(!(tmp = malloc(tmplen))) {
    sprintf(err_msg, "Out of Memory");
    exit(-1);
  }*/

  while ((hres = gethostbyname2_r(hptr, family, &hostbuf, tmp, tmplen, &remote_server_ent, &herr) ) == ERANGE) {
    /*tmplen *=2;
    if(!(tmp = realloc(tmp, tmplen))){
      sprintf(err_msg, "Out of Memory");
      exit(-1);
    }*/
    sprintf(err_msg, "Error: gethostbyname2_r() return ERANGE for server_name '%s'.", server_name);
    return (0);
  }
  if(!remote_server_ent)
  {
    family = AF_INET6;
    while ((hres = gethostbyname2_r(hptr, family, &hostbuf, tmp, tmplen, &remote_server_ent, &herr) ) == ERANGE) {
      /*tmplen *=2;
      if(!(tmp = realloc(tmp, tmplen))){
        sprintf(err_msg, "Out of Memory");
        exit(-1);
      }*/
      sprintf(err_msg, "Error: gethostbyname2_r() return ERANGE for server_name '%s'.", server_name);
      return (0);
    }
  }
  if(!remote_server_ent){
    sprintf(err_msg, "Error in getting server socket address of server '%s' - %s", hptr, hstrerror(h_errno));
    return (0);
  }

  if (family == AF_INET) 
  {
    sin = (struct sockaddr_in *) saddr;
    sin->sin_family = AF_INET;
    sin->sin_port = htons(server_port);;
    bcopy( (char *)remote_server_ent->h_addr, (char *)&(sin->sin_addr), remote_server_ent->h_length );
    return (sizeof(struct sockaddr_in));
  } 
  //else if (remote_server_ent->h_addrtype == AF_INET6) i
  else if (family == AF_INET6)
  {
    saddr->sin6_family = AF_INET6;
    saddr->sin6_port = htons(server_port);;
      bcopy( (char *)remote_server_ent->h_addr, (char *)&(saddr->sin6_addr), remote_server_ent->h_length );
      return (sizeof(struct sockaddr_in6));
  } else {
    sprintf(err_msg, "Error in getting server socket address of server '%s' - Unsupported protocol address family %d", hptr, (int)(remote_server_ent->h_addrtype));
    return (0);
  }
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
 *-------------------------------------------------------------------*/
int nslb_tcp_client_ex_r(char *server_name, int default_port, int timeout_val, char *err_msg)
{
int fd;
//char *ptr;
//char buf[256];
//int server_port;
struct sockaddr_in6  remote_server_addr;
//struct hostent     *remote_server_ent;
	//strcpy(buf, server_name);

        //memset(&remote_server_addr, 0, sizeof(remote_server_addr));
        if ((fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
           sprintf(err_msg, "socket (TCP) err : %s", strerror(errno));
           return -1;
        }

#if 0
	ptr = index(buf, ':'); //Check if port is provided
	if (ptr)  {
	    *ptr = '\0';
	    server_port = atoi(ptr+1);
	} else { //use default port 80
	    if (default_port < 0 ) {
		fprintf(stderr, "tcp_client:server (%s) has no port and no default portprovided\n", server_name);
		close(fd);
        	return (-1);
	    }
	    server_port = default_port;
	}

    	if ((remote_server_ent = gethostbyname(buf)) == NULL ) {
        	perror("tcp_client:gethostbyname");
		fprintf(stderr, "host is %s\n", buf);
		close(fd);
        	return (-1);
    	 }

    	 bcopy( (char *)  remote_server_ent->h_addr,
         	(char *) &remote_server_addr.sin_addr,
               	remote_server_ent->h_length );
    	 remote_server_addr.sin_family = remote_server_ent->h_addrtype;
    	 remote_server_addr.sin_port = htons(server_port);
#endif
        if (!nslb_fill_sockaddr_ex_r(&remote_server_addr, server_name, default_port, err_msg)) {
	    close(fd);
            return (-1);
    	}

        if(timeout_val > 0)
        {
            struct timeval tv;
            memset(&tv, 0, sizeof(struct timeval));
            int ret = 0;
 
            tv.tv_sec = timeout_val;  /* timeout_val Secs Timeout */
            /*
            SO_SNDTIMEO:
              Sets the timeout value specifying the amount of time that an output function blocks because flow control prevents data from being sent. If a send operation has blocked for this time, it shall return with a partial count or with errno set to [EAGAIN] or [EWOULDBLOCK] if no data is sent. The default for this option is zero, which indicates that a send operation shall not time out. This option stores a timeval structure. Note that not all implementations allow this option to be set.
            */
            // fprintf(stderr,"Before setting send timeout\n");
            ret = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
            // fprintf(stderr,"Before setting send timeout\n");
            if(ret < 0)
            {
                fprintf(stderr, "Error in setting socket send timeout using setsockopt, Ignored. Error = %s", strerror(errno));
            }
         
            /*
            SO_RCVTIMEO:
              Sets the timeout value that specifies the maximum amount of time an input function waits until it completes. It accepts a timeval structure with the number of seconds and microseconds specifying the limit on how long to wait for an input operation to complete. If a receive operation has blocked for this much time without receiving additional data, it shall return with a partial count or errno set to [EAGAIN] or [EWOULDBLOCK] if no data is received. The default for this option is zero, which indicates that a receive operation shall not time out. This option takes a timeval structure. Note that not all implementations allow this option to be set.
            */
            // fprintf(stderr,"Before setting recv timeout\n");
            ret = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
            // fprintf(stderr,"Before setting recv timeout\n");
            if(ret < 0)
            {
                fprintf(stderr, "Error in setting socket recieve timeout using setsockopt, Ignored. Error = %s", strerror(errno));

            }
        }

	//printf("Connecting to %s (%d)\n", server_name, default_port);
        if ((connect(fd, (struct sockaddr *)&remote_server_addr, sizeof(remote_server_addr))) < 0 ) 
        {
          // fprintf(stderr, "connect error ...........\n");
          //perror("connect: ");
          sprintf(err_msg, "tcp_client(): Error in making connection to server %s. Error = %s", server_name, strerror(errno));
	  close(fd);
          return (-1);
        }
	return fd;
}

/*------------------------------------------------------------------- 
 * Purpose   : 
 * Input     :  
 * Output    :   
   One who needs err_msg need to call tcp_client_ex
 *-------------------------------------------------------------------*/
int nslb_tcp_client_r(char *server_name, int default_port)
{
  char err_msg[1024]="\0";
  int ret;
  
  if((ret = nslb_tcp_client_ex_r(server_name, default_port, -1, err_msg)) < 0)
    fprintf(stderr, "%s", err_msg);

  return(ret);
}
