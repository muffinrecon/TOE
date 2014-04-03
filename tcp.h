#include <stdio.h>
#include <stdlib.h>
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

struct tcp_pcb {
	int sd;
	char *interface, *target, *src_ip, *dst_ip;
	uint8_t *src_mac, *dst_mac, *ether_frame_in, *ether_frame_out;
	int *ip_flags, *tcp_flags;
	uint16_t in_port, out_port;
	struct sockaddr_ll device;
	int seq;
	uint16_t sport;
	uint16_t dport; 
};

void tcp_tmr(void);

// connection
struct tcp_pcb *tcp_new(void);
int tcp_bind(struct tcp_pcb*, char*, uint16_t, char*);
struct tcp_pcb *tcp_listen(struct tcp_pcb *);
void tcp_accept(struct tcp_pcb *);
int tcp_connect(struct tcp_pcb *, char *);

// Sending TCP data 
void tcp_sent (struct tcp_pcb *);
void tcp_sndbuf(void);
void tcp_write(void);
