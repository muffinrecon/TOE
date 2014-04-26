#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>           // close()
#include <string.h>           // strcpy, memset(), and memcpy()
#include <netdb.h>            // struct addrinfo
#include <sys/types.h>        // needed for socket(), uint8_t, uint16_t
#include <sys/socket.h>       // needed for socket()
#include <netinet/in.h>       // IPPROTO_RAW, INET_ADDRSTRLEN
#include <netinet/ip.h>       // IP_MAXPACKET (which is 65535)
#define __FAVOR_BSD
#include <netinet/tcp.h>      // struct tcphdr 
#include <arpa/inet.h>        // inet_pton() and inet_ntop()
#include <sys/ioctl.h>        // macro ioctl is defined
#include <bits/ioctls.h>      // defines values for argument "request" of ioctl.
#include <net/if.h>           // struct ifreq
#include <linux/if_ether.h>   // ETH_P_ARP = 0x0806
#include <linux/if_packet.h>  // struct sockaddr_ll (see man 7 packet)
#include <net/ethernet.h>
#include <errno.h>            // errno, perror()

#define ETH_HDRLEN 14		// Ethernet header lenght
#define IP4_HDRLEN 20		// IPv4 header length
#define TCP_HDRLEN 20		// TCP header length	

typedef enum {CLOSED, SYN_SENT, OPEN} state_t;

struct tcp_ctrl{
	int sd;
	char *interface, *target, *src_ip, *dst_ip;
	uint8_t *src_mac, *dst_mac, *ether_frame;
	int *ip_flags, *tcp_flags;
	struct sockaddr_ll device;
	int seq, rcv_ack;
	uint16_t sport, dport;
	uint8_t *sdbuffer;
  	struct tcphdr *tcphdr;
	struct ip *iphdr;	
	int mtu;
	state_t state; 
};

// Initiatiate connection
struct tcp_ctrl *tcp_new_rawsck(void);
int tcp_bind_rawsck(struct tcp_ctrl*, char*, uint16_t, char*);
int tcp_connect_rawsck(struct tcp_ctrl *, char *);

// Accept connection
struct tcp_ctrl *tcp_listen_rawsck(struct tcp_ctrl *);
void tcp_accept_rawsck(struct tcp_ctrl *);

// Sending TCP data 
int tcp_write_rawsck(struct tcp_ctrl *, void *, int);

// Receiving data
int tcp_rcv_rawsck(struct tcp_ctrl *, uint8_t *, int);

// Closing connection
int tcp_close_rawsck(struct tcp_ctrl *);

