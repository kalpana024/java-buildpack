#ifndef NSLB_SOCK_H
#define NSLB_SOCK_H

#define NSLB_SOCK_IP_PORT_LEN 512

#define NSLB_CON_CONNECTED 1
#define NSLB_CON_CONNECTING 2

#define NSLB_CON_DOUBLE_CHECK_ENABLE  1
#define NSLB_CON_DOUBLE_CHECK_DISABLE 0

#include <netinet/in.h>

extern int nslb_nb_open_socket(int family, char *err_msg);
extern int nslb_nb_connect(int sock_fd, char *server_ip, int server_port, int *con_state, char *err_msg);
extern int nslb_tcp_listen_ex(int local_port, int backlog, char *ip_addr, char* err_msg);
extern int nslb_tcp_listen(int local_port, int backlog, char* err_msg);
extern inline int nslb_Tcp_listen_ex(int local_port, int backlog, char *ip_addr, char* err_msg);
extern inline int nslb_Tcp_listen(int local_port, int backlog, char* err_msg);
extern int nslb_tcp_listen6(int local_port, int backlog);
extern inline int nslb_Tcp_listen6(int local_port, int backlog);
extern inline void nslb_Fcntl (int fd, int cmd, long arg);
extern int nslb_fill_sockaddr(struct sockaddr_in6 * saddr, char *server_name, int default_port);
extern int nslb_fill_sockaddr_ex(struct sockaddr_in6 * saddr, char *server_name, int default_port, char *err_msg);
extern int nslb_tcp_client_ex(char *server_name, int default_port, int timeout_val, char *err_msg);
extern int nslb_tcp_client(char *server_name, int default_port);
extern int nslb_udp_server (unsigned short port, int no_delay, char *ip_addr);
extern int nslb_udp_server6(unsigned short port, int no_delay, char *ip_addr);
extern int nslb_udp_client(char *server_name, int default_port, int no_delay);
extern char *nslb_sockaddr_to_ip(const struct sockaddr *sa, int give_port);
extern char *nslb_sock_ntop(const struct sockaddr *sa);
extern unsigned int nslb_get_sigfig_addr (struct sockaddr_in6 *saddr);
extern char* nslb_get_src_addr(int fd);
extern char* nslb_get_src_addr_ex(int fd, int give_port);
extern char* nslb_get_dest_addr(int fd);
extern char* nslb_get_dest_addr_ex(int fd, int give_port);
extern char *nslb_get_tcpinfo(int fd);
extern int nslb_fill_sockaddr_ex_r(struct sockaddr_in6 * saddr, char *server_name, int default_port, char *err_msg);
extern int nslb_tcp_client_ex_r(char *server_name, int default_port, int timeout_val, char *err_msg);
extern int nslb_tcp_client_r(char *server_name, int default_port);
extern char * nslb_split_host_port (char *svr, int *hport);
#define SIN6_LEN
#define SA  struct sockaddr
#endif 

