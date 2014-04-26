#include "tcp_rawsck.h"
#include "arp.h"
#include <string.h>

#define SYN 0x02
#define ACK 0x10
#define SYNACK 0x12
#define FINACK 0x11

char *allocate_strmem (int);
uint8_t *allocate_ustrmem (int);
int *allocate_intmem (int);

uint16_t checksum (uint16_t *, int);
uint16_t tcp4_checksum(struct ip, struct tcphdr, uint8_t *, int);
uint16_t tcp2_checksum(struct ip, struct tcphdr);

// Filling packets 
int fill_iphdr(struct tcp_ctrl *, int);
int fill_tcphdr(struct tcp_ctrl *, uint8_t flags, int len);
int fill_ethhdr(struct tcp_ctrl *, int len);

// Establishing connection
void sd_ARP_rq(struct tcp_ctrl *);
void rcv_ARP_asw(struct tcp_ctrl *);
void sd_SYN_pck(struct tcp_ctrl *);
int rcv_SYNACK_pck(struct tcp_ctrl *);
int rcv_ACK_pck(struct tcp_ctrl *);
int sd_FINACK_pck(struct tcp_ctrl *);
int rcv_FINACK_pck(struct tcp_ctrl *);
void sd_ACK_pck(struct tcp_ctrl *, int);

struct tcp_ctrl *tcp_new_rawsck(void) {
	printf("Entering : tcp_new()\n");
	
	struct tcp_ctrl *tcp_ctrl = malloc(sizeof(struct tcp_ctrl));
	if (tcp_ctrl == NULL) {
		perror("malloc() failed");
		exit (EXIT_FAILURE);	
	}

	tcp_ctrl -> seq = random();
	tcp_ctrl -> rcv_ack = 0;
	tcp_ctrl -> mtu = 0;
	tcp_ctrl -> state = CLOSED;
  	// Allocate memory for various arrays.
	tcp_ctrl -> iphdr = (struct ip *) malloc(sizeof(struct ip)); 
	if (tcp_ctrl -> iphdr == NULL) {
		perror("Memory Allocation for tcphdr failed");
		exit(EXIT_FAILURE);
	}
	tcp_ctrl -> tcphdr =(struct tcphdr *) malloc(sizeof(struct tcphdr)); 
	if (tcp_ctrl -> tcphdr == NULL) {
		perror("Memory Allocation for tcphdr failed");
		exit(EXIT_FAILURE);
	} 
  	tcp_ctrl -> src_mac = allocate_ustrmem(6);
  	tcp_ctrl -> dst_mac = allocate_ustrmem(6);
  	tcp_ctrl -> ether_frame = allocate_ustrmem(IP_MAXPACKET);
  	tcp_ctrl -> sdbuffer = allocate_ustrmem(IP_MAXPACKET);
  	tcp_ctrl -> interface = allocate_strmem(40);
  	tcp_ctrl -> target = allocate_strmem(40);
  	tcp_ctrl -> src_ip = allocate_strmem(INET_ADDRSTRLEN);
  	tcp_ctrl -> dst_ip = allocate_strmem(INET_ADDRSTRLEN);
  	tcp_ctrl -> ip_flags = allocate_intmem (4);
  	tcp_ctrl -> tcp_flags = allocate_intmem (8); 

	if ((tcp_ctrl->sd = socket (PF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
		perror ("socket() failed");
		exit (EXIT_FAILURE);
	} 
	
	printf("Exiting : tcp_new()\n");
	return tcp_ctrl;
}

int tcp_bind_rawsck(struct tcp_ctrl* tcp_ctrl, char *ip_addr, uint16_t sport, char *interface) {
	printf("Entering : tcp_bind\n");
	
	int sd;
	struct ifreq ifr;

	strcpy (tcp_ctrl->src_ip, ip_addr);		
	strcpy (tcp_ctrl->interface, interface);
	tcp_ctrl -> sport = sport;

	if ((sd = socket (AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0) {
		perror ("socket() failed to get socket descriptor for using ioctl()");
		exit (EXIT_FAILURE);
	} 
	
	memset(&ifr, 0, sizeof(struct ifreq));
	snprintf(ifr.ifr_name, sizeof (ifr.ifr_name), "%s", interface);
	if ((ioctl (sd, SIOCGIFHWADDR, &ifr)) < 0) {
		perror ("ioctl() failed to get source MAC address ");
		return (EXIT_FAILURE);
	}
	memcpy(tcp_ctrl->src_mac, ifr.ifr_hwaddr.sa_data, 6 * sizeof(uint8_t));

		
   	// DEBBUG Report source MAC address to stdout.
   	/*int i;
   	printf ("MAC address for interface %s is ", interface);
   	for (i=0; i<5; i++) {
     		printf ("%02x:", tcp_ctrl->src_mac[i]);
  	}
  	printf ("%02x\n", tcp_ctrl->src_mac[5]);
	*/

   	// Find interface index from interface name and store index in
   	// struct sockaddr_ll device, which will be used as an argument of sendto().
  	
	memset (&(tcp_ctrl->device), 0, sizeof (struct sockaddr_ll));
   	if (((tcp_ctrl->device).sll_ifindex = if_nametoindex (tcp_ctrl->interface)) == 0) {
   	  perror ("if_nametoindex() failed to obtain interface index ");
   	  exit (EXIT_FAILURE);
  	}
   	printf ("Index for interface %s is %i\n", tcp_ctrl->interface, (tcp_ctrl->device).sll_ifindex);

  	// Use ioctl() to get interface maximum transmission unit (MTU).
  	memset (&ifr, 0, sizeof (ifr));
  	strcpy (ifr.ifr_name, interface);
  	if (ioctl (sd, SIOCGIFMTU, &ifr) < 0) {
   		 perror ("ioctl() failed to get MTU ");
    		return (EXIT_FAILURE);
  	}
 	tcp_ctrl -> mtu = ifr.ifr_mtu;
 	printf ("Current MTU of interface %s is: %i\n", interface, tcp_ctrl -> mtu);
	
	close(sd);

	printf("Exiting : tcp_bind()\n");
   	return 0;
}

int tcp_connect_rawsck(struct tcp_ctrl *tcp_ctrl, char* url) {
	
	printf("Entering : tcp_connect()\n");
	
	int status;

	struct addrinfo hints, *res;
	struct sockaddr_in *ipv4;
	void *tmp;

	strcpy(tcp_ctrl->target, url);
	tcp_ctrl -> dport = 80;

	// Fill out hints for getaddrinfo()
	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = hints.ai_flags | AI_CANONNAME;

	// Resolve target using getaddrinfo()
   	if ((status = getaddrinfo(tcp_ctrl->target, NULL, &hints, &res)) != 0) {
		fprintf (stderr, "getaddrinfo() failed: %s\n", gai_strerror(status));
		exit(EXIT_FAILURE);
	}
	ipv4 = (struct sockaddr_in *) res->ai_addr;
	tmp = &(ipv4 -> sin_addr);
	
	strcpy(tcp_ctrl -> dst_ip, inet_ntoa(ipv4->sin_addr));
	
	freeaddrinfo(res);
	
	// Fill out sockaddr_ll.
	(tcp_ctrl->device).sll_family = AF_PACKET;
	memcpy ((tcp_ctrl->device).sll_addr, tcp_ctrl -> src_mac, 6 * sizeof (uint8_t));
	(tcp_ctrl->device).sll_halen = htons(6);	
	
	sd_ARP_rq(tcp_ctrl);
	rcv_ARP_asw(tcp_ctrl);
	sd_SYN_pck(tcp_ctrl);
	// Modify function synack
	int ack = rcv_SYNACK_pck(tcp_ctrl);
	tcp_ctrl -> rcv_ack = ack;
	printf("ACK value after receiving SYNACK : %u\n", tcp_ctrl -> rcv_ack);
	sd_ACK_pck(tcp_ctrl, tcp_ctrl -> rcv_ack);

	printf("Exiting tcp_connect()\n");
	
	return 0;
}

int tcp_close_rawsck(struct tcp_ctrl *tcp_ctrl) {
	sd_FINACK_pck(tcp_ctrl);
	rcv_FINACK_pck(tcp_ctrl);
	sd_FINACK_pck(tcp_ctrl);
	tcp_ctrl->seq++;
	tcp_ctrl->rcv_ack++;
	sd_ACK_pck(tcp_ctrl, tcp_ctrl -> rcv_ack);
	rcv_ACK_pck(tcp_ctrl);
	sd_ACK_pck(tcp_ctrl, tcp_ctrl -> rcv_ack);
	return 0;
} 

int tcp_write_rawsck(struct tcp_ctrl *tcp_ctrl, void *data, int len) {
	
	printf("Entering : tcp_write()\n");
  
	int status, i, frame_length;
	int max_payload = tcp_ctrl->mtu - TCP_HDRLEN - IP4_HDRLEN - ETH_HDRLEN;
	printf("max_payload : %d\n", max_payload);
	if (len > max_payload) {
		perror("Request too long");
		exit(EXIT_FAILURE);
	}
	
	memcpy(tcp_ctrl->sdbuffer, (uint8_t *) data, len);
	fill_iphdr(tcp_ctrl, len); 	
	fill_tcphdr(tcp_ctrl, ACK, len);
	fill_ethhdr(tcp_ctrl, len);
	
  	// Send ethernet frame to socket.
	frame_length = ETH_HDRLEN + IP4_HDRLEN + TCP_HDRLEN + len;
	int success;
  	if ((success = sendto (tcp_ctrl->sd, tcp_ctrl->ether_frame, frame_length, 0, (struct sockaddr *) &(tcp_ctrl->device), sizeof (struct sockaddr_ll))) <= 0) {
    		perror ("sendto() failed");
   	 	exit (EXIT_FAILURE);
 	}
	tcp_ctrl -> seq += len;
	//if (tcp_ctrl -> state = SYN_SENT) tcp_ctrl -> state = OPEN;

	rcv_ACK_pck(tcp_ctrl); 

	printf("Exiting : tcp_write()\n");
	return success;
}

int tcp_rcv_rawsck(struct tcp_ctrl *tcp_ctrl, uint8_t *data, int max_len){
	printf("Entering : tcp_rcv()\n");
	int len = 0;
	int bytes, payload;
        	
	struct tcphdr *tcphdr;
	tcphdr = (struct tcphdr *) (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN);
	while ( len < max_len ) {
		if ((bytes = recv(tcp_ctrl -> sd, tcp_ctrl -> ether_frame, IP_MAXPACKET, 0)) < 0) {
			printf("ERROR");
			perror("recv() failed");
			exit (EXIT_FAILURE);
		}
		else {
		     // Filter TCP packets
		     if ((((tcp_ctrl->ether_frame[12]) << 8) + tcp_ctrl -> ether_frame[13]) == ETH_P_IP) {
			printf("th_seq : %u\n", ntohl(tcphdr -> th_seq));
			printf("rcv_ack: %u\n", tcp_ctrl -> rcv_ack);
		     	if ((ntohl(tcphdr -> th_seq)) == tcp_ctrl -> rcv_ack) {
		     		payload = bytes - TCP_HDRLEN - IP4_HDRLEN - ETH_HDRLEN;
		     		printf("payload : %d\n", payload);
		     		if( payload < 536 ) {
		    			memcpy(data + len, (uint8_t *) tcphdr + TCP_HDRLEN, payload); 
					len += payload;
					tcp_ctrl -> rcv_ack += (payload);
					sd_ACK_pck(tcp_ctrl, tcp_ctrl -> rcv_ack);
					printf("Breaking\n"); 		
					break;
		     		}
		     		memcpy(data + len, (uint8_t *) tcphdr + TCP_HDRLEN, payload); 
		     		printf("len : %d\n", len);
		     		len += payload;
	             		tcp_ctrl -> rcv_ack += payload;
		    		sd_ACK_pck(tcp_ctrl, tcp_ctrl -> rcv_ack);
		    	}
		     	else {
				printf("DROP CONNECTION\n");
				return -1;
		     	}	 
		    }
		}
	}
	if (len == max_len) {
		perror("Buffer complet");
		exit(EXIT_FAILURE);
	}
	printf("Exiting : tcp_rcv()\n");
	return len;
}

fill_iphdr(struct tcp_ctrl *tcp_ctrl, int len) {
	struct ip *iphdr = tcp_ctrl -> iphdr;
	int ip_flags[4];
	int status;
  	// IPv4 header length (4 bits): Number of 32-bit words in header = 5
  	iphdr -> ip_hl = IP4_HDRLEN / sizeof (uint32_t);
	// Internet Protocol version (4 bits): IPv4
  	iphdr -> ip_v = 4;
	// Type of service (8 bits)
  	iphdr -> ip_tos = 0;
	// Total length of datagram (16 bits): IP header + TCP header
	iphdr -> ip_len = htons (IP4_HDRLEN + TCP_HDRLEN + len); 
	// ID sequence number (16 bits): unused, since single datagram
  	iphdr -> ip_id = htons (0); 
	// Flags, and Fragmentation offset (3, 13 bits): 0 since single datagram
	// Zero (1 bit)
  	ip_flags[0] = 0;
	// Do not fragment flag (1 bit)
  	ip_flags[1] = 0;
	// More fragments following flag (1 bit)
  	ip_flags[2] = 0;
	// Fragmentation offset (13 bits)
  	ip_flags[3] = 0;

  	iphdr -> ip_off = htons ((ip_flags[0] << 15)
                      	+ (ip_flags[1] << 14)
                    	+ (ip_flags[2] << 13)
                        +  ip_flags[3]);

  	// Time-to-Live (8 bits): default to maximum value
  	iphdr -> ip_ttl = 255;
	// Transport layer protocol (8 bits): 6 for TCP
  	iphdr -> ip_p = IPPROTO_TCP;

  	// Source IPv4 address (32 bits)
  	if ((status = inet_pton (AF_INET, tcp_ctrl -> src_ip, &(iphdr -> ip_src))) != 1) {
    		fprintf (stderr, "inet_pton() failed 1.\nError message: %s", strerror (status));
    		exit (EXIT_FAILURE);
 	}
	// Destination IPv4 address (32 bits)
  	if ((status = inet_pton (AF_INET, tcp_ctrl -> dst_ip, &(iphdr -> ip_dst))) != 1) {
   		fprintf (stderr, "inet_pton() failed 2.\nError message: %s", strerror (status));
    		exit (EXIT_FAILURE);
 	 }
	// IPv4 header checksum (16 bits): set to 0 when calculating checksum
  	iphdr -> ip_sum = 0;
  	iphdr -> ip_sum = checksum ((uint16_t *) iphdr, IP4_HDRLEN);
	
	return 0;
}	

int fill_tcphdr(struct tcp_ctrl *tcp_ctrl, uint8_t flags, int len) {

	// TCP header
  	struct tcphdr *tcphdr= tcp_ctrl -> tcphdr;
  	int tcp_flags[8];

  	// Source port number (16 bits)
  	tcphdr -> th_sport = htons (tcp_ctrl -> sport);
	// Destination port number (16 bits)
  	tcphdr -> th_dport = htons (tcp_ctrl -> dport);  
	// Sequence number (32 bits)
  	tcphdr -> th_seq= htonl(tcp_ctrl -> seq);
	// Acknowledgement number (32 bits): 0 in first packet of SYN/ACK process
	// Isolate the ACK flag and put 0 instead if the ACK flag is not on
	if (flags && 0x10) { tcphdr -> th_ack = htonl (tcp_ctrl -> rcv_ack); }
	else { tcphdr -> th_ack = htonl(0); }
	// Reserved (4 bits): should be 0
  	tcphdr -> th_x2 = 0;
	// Data offset (4 bits): size of TCP header in 32-bit words
  	tcphdr -> th_off = TCP_HDRLEN / 4;
	// Flags
  	tcphdr -> th_flags = flags;
  	// Window size (16 bits)
  	tcphdr -> th_win = htons (14600);
	// Urgent pointer (16 bits): 0 (only valid if URG flag is set)
  	tcphdr -> th_urp = htons (0);
	// TCP checksum (16 bits)
  	tcphdr -> th_sum = 0;
  	tcphdr -> th_sum = tcp4_checksum (*(tcp_ctrl -> iphdr), *(tcp_ctrl -> tcphdr), tcp_ctrl -> sdbuffer, len);
  
	return 0;
}

int fill_ethhdr(struct tcp_ctrl *tcp_ctrl, int len) {
	
	// Fill out ethernet frame header.
	// Destination and Source MAC addresses
  	memcpy (tcp_ctrl -> ether_frame, tcp_ctrl -> dst_mac, 6 * sizeof (uint8_t));
  	memcpy (tcp_ctrl -> ether_frame + 6, tcp_ctrl -> src_mac, 6 * sizeof (uint8_t));
	// Next is ethernet type code (ETH_P_IP for IPv4).
  	// http://www.iana.org/assignments/ethernet-numbers
  	tcp_ctrl -> ether_frame[12] = ETH_P_IP / 256;
  	tcp_ctrl -> ether_frame[13] = ETH_P_IP % 256;
	// Next is ethernet frame data (IPv4 header + TCP header).
	// IPv4 header
  	memcpy (tcp_ctrl -> ether_frame + ETH_HDRLEN, tcp_ctrl -> iphdr, IP4_HDRLEN * sizeof (uint8_t));
	// TCP header
  	memcpy (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN, tcp_ctrl -> tcphdr, TCP_HDRLEN * sizeof (uint8_t));
	memcpy (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN + TCP_HDRLEN, tcp_ctrl-> sdbuffer, len * sizeof(uint8_t));

}
int sd_FINACK_pck(struct tcp_ctrl *tcp_ctrl) {

	printf("Entering : sd_FINACK_pck()\n");
	
  	int status, i, frame_length, bytes;

	fill_iphdr(tcp_ctrl, 0);
 	fill_tcphdr(tcp_ctrl, FINACK, 0);
	fill_ethhdr(tcp_ctrl, 0);	


  	// Send ethernet frame to socket.
  	frame_length = ETH_HDRLEN + IP4_HDRLEN + TCP_HDRLEN;
  	if ((bytes = sendto (tcp_ctrl->sd, tcp_ctrl->ether_frame, frame_length, 0, (struct sockaddr *) &(tcp_ctrl->device), sizeof (struct sockaddr_ll))) <= 0) {
    		perror ("sendto() failed");
    		exit (EXIT_FAILURE);
  	}
	
	printf("Exiting : sd_FINACK_pck()\n");
}

void sd_SYN_pck(struct tcp_ctrl *tcp_ctrl) {

	printf("Entering : sd_SYN_pck()\n");

  	int status, i, frame_length, bytes;
	
	fill_iphdr(tcp_ctrl, 0);
	fill_tcphdr(tcp_ctrl, SYN, 0);
  	fill_ethhdr(tcp_ctrl,0);	
	
  	// Send ethernet frame to socket.
  	// Ethernet frame length = ethernet header (MAC + MAC + ethernet type) + ethernet data (IP header + TCP header)
  	frame_length = ETH_HDRLEN + IP4_HDRLEN + TCP_HDRLEN;
  	if ((bytes = sendto (tcp_ctrl->sd, tcp_ctrl->ether_frame, frame_length, 0, (struct sockaddr *) &(tcp_ctrl->device), sizeof (struct sockaddr_ll))) <= 0) {
    		perror ("sendto() failed");
    		exit (EXIT_FAILURE);
  	}
	
	//tcp_ctrl -> state = SYN_SENT;
	printf("Exiting : sd_SYN_pck()\n");
}

int rcv_ACK_pck(struct tcp_ctrl *tcp_ctrl) {
  printf("Entering : rcv_ACK_pck()\n");
  
  int status;
  struct tcphdr *tcphdr;
  tcphdr= (struct tcphdr *) (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN);
  struct ip *ip;
  ip = (struct ip *) (tcp_ctrl -> ether_frame + ETH_HDRLEN);
  do {
	if ((status = recv (tcp_ctrl -> sd, tcp_ctrl -> ether_frame, IP_MAXPACKET, 0)) < 0) {
      		if (errno == EINTR) {
       			memset (tcp_ctrl -> ether_frame, 0, IP_MAXPACKET * sizeof (uint8_t));
       			continue;  // Something weird happened, but let's try again.
 		} else {
       			perror ("recv() failed:");
       	 		exit (EXIT_FAILURE);
     		}
    	}
  } while (((((tcp_ctrl -> ether_frame[12]) << 8) + tcp_ctrl -> ether_frame[13]) != ETH_P_IP)
	||(strcmp(inet_ntoa(ip -> ip_src), tcp_ctrl -> dst_ip) != 0)
	||(strcmp(inet_ntoa(ip -> ip_dst), tcp_ctrl -> src_ip) != 0) // Maybe we can remove this condition 
	||(memcmp(tcp_ctrl -> ether_frame, tcp_ctrl -> src_mac, 6) != 0)   // In case we have several MAC (possible ?)
	||(tcphdr->th_flags != ACK));
  printf("Exiting : rcv_ACK_pck()\n");
  return tcp_ctrl -> rcv_ack + status;
}

int rcv_FINACK_pck(struct tcp_ctrl *tcp_ctrl) {
  
  printf("Entering : rcv_FINACK_pck()\n");
  
  int status;
  struct tcphdr *tcphdr;
  tcphdr= (struct tcphdr *) (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN);
  struct ip *ip;
  ip = (struct ip *) (tcp_ctrl->ether_frame + ETH_HDRLEN);
  do {
	if ((status = recv (tcp_ctrl->sd, tcp_ctrl->ether_frame, IP_MAXPACKET, 0)) < 0) {
      		if (errno == EINTR) {
       			memset (tcp_ctrl->ether_frame, 0, IP_MAXPACKET * sizeof (uint8_t));
       			continue;  // something weird happened, but let's try again.
 		} else {
       			perror ("recv() failed:");
       	 		exit (EXIT_FAILURE);
     		}
    	}

  }
  while (((((tcp_ctrl -> ether_frame[12]) << 8) + tcp_ctrl -> ether_frame[13]) != ETH_P_IP)
	||(strcmp(inet_ntoa(ip -> ip_src), tcp_ctrl -> dst_ip) != 0)
	||(strcmp(inet_ntoa(ip->ip_dst), tcp_ctrl -> src_ip) != 0) // Maybe we can remove this condition 
	||(memcmp(tcp_ctrl -> ether_frame, tcp_ctrl -> src_mac, 6) != 0)   // In case we have several MAC (possible ?)
	||(tcphdr->th_flags != FINACK)); 
 
  printf("Exiting : rcv_FINACK_pck()\n");
  return 0; 
  	
}

int rcv_SYNACK_pck(struct tcp_ctrl *tcp_ctrl) {
  
  printf("Entering : rcv_SYNACK_pck()\n");
  
  int status;
  struct tcphdr *tcphdr;
  tcphdr= (struct tcphdr *) (tcp_ctrl -> ether_frame + ETH_HDRLEN + IP4_HDRLEN);
  struct ip *ip;
  ip = (struct ip *) (tcp_ctrl -> ether_frame + ETH_HDRLEN);
  while (((((tcp_ctrl->ether_frame[12]) << 8) + tcp_ctrl->ether_frame[13]) != ETH_P_IP)
	||(strcmp(inet_ntoa(ip->ip_src), tcp_ctrl -> dst_ip) != 0)
	||(strcmp(inet_ntoa(ip->ip_dst), tcp_ctrl -> src_ip) != 0) // In case we have several IP on the same machine
	||(memcmp(tcp_ctrl -> ether_frame, tcp_ctrl -> src_mac, 6) != 0)   // In case we have several MAC (possible ?)
	||(tcphdr -> th_flags != SYNACK)) {
 
	if ((status = recv (tcp_ctrl->sd, tcp_ctrl -> ether_frame, IP_MAXPACKET, 0)) < 0) {
      		if (errno == EINTR) {
       			memset (tcp_ctrl->ether_frame, 0, IP_MAXPACKET * sizeof (uint8_t));
       			continue;  // Something weird happened, but let's try again.
 		} else {
       			perror ("recv() failed:");
       	 		exit (EXIT_FAILURE);
     		}
    	}
  }
  tcp_ctrl->seq++;
  return ntohl(tcphdr->th_seq) + 1; 	
}


void sd_ACK_pck(struct tcp_ctrl *tcp_ctrl, int ack) {
  int status, i, frame_length, bytes;

  fill_iphdr(tcp_ctrl, 0);
  fill_tcphdr(tcp_ctrl, ACK, 0);
  fill_ethhdr(tcp_ctrl, 0);

  
  // Send ethernet frame to socket.
  frame_length = ETH_HDRLEN + IP4_HDRLEN + TCP_HDRLEN; 
  if ((bytes = sendto (tcp_ctrl -> sd, tcp_ctrl -> ether_frame, frame_length, 0, (struct sockaddr *) &(tcp_ctrl->device), sizeof (struct sockaddr_ll))) <= 0) {
    perror ("sendto() failed");
    exit (EXIT_FAILURE);
  }	
}

void sd_ARP_rq(struct tcp_ctrl *tcp_ctrl) {
	
	printf("Entering : sd_ARP_rq()\n");
	int status;
	arp_hdr arphdr;
		
  	// Set destination MAC address: broadcast address
  	memset (tcp_ctrl->dst_mac, 0xff, 6 * sizeof (uint8_t));

	// Fill ARP header
	// Hardware type (16 bits): 1 for ethernet
 	arphdr.htype = htons (1);

 	// Protocol type (16 bits): 2048 for IP
  	arphdr.ptype = htons (ETH_P_IP);

  	// Hardware address length (8 bits): 6 bytes for MAC address
  	arphdr.hlen = 6;

  	// Protocol address length (8 bits): 4 bytes for IPv4 address
  	arphdr.plen = 4;

  	// OpCode: 1 for ARP request
 	arphdr.opcode = htons (ARPOP_REQUEST);

  	// Sender hardware address (48 bits): MAC address
  	memcpy (arphdr.sender_mac, tcp_ctrl->src_mac, 6 * sizeof (uint8_t));

  	// Sender protocol address (32 bits)
 	// See getaddrinfo() resolution of src_ip.

 	 // Target hardware address (48 bits): zero, since we don't know it yet.
  	memset(arphdr.target_mac, 0, 6 * sizeof (uint8_t));

	// Source IP address
  	if ((status = inet_pton (AF_INET, tcp_ctrl->src_ip, arphdr.sender_ip)) != 1) {
    		fprintf (stderr, "inet_pton() source IP address.\nError message: %s", strerror (status));
    		exit (EXIT_FAILURE);
  	}


	// Fill Ethernet header
	int frame_length, bytes;
	
  	// Ethernet frame length = ethernet header (MAC + MAC + ethernet type) + ethernet data (ARP header)
  	frame_length = ETH_HDRLEN+ ARP_HDRLEN;

  	// Destination and Source MAC addresses
 	memcpy (tcp_ctrl->ether_frame, tcp_ctrl->dst_mac, 6 * sizeof (uint8_t));
  	memcpy (tcp_ctrl->ether_frame + 6, tcp_ctrl->src_mac, 6 * sizeof (uint8_t));

  	// Next is ethernet type code (ETH_P_ARP for ARP).
  	// http://www.iana.org/assignments/ethernet-numbers
  	tcp_ctrl -> ether_frame[12] = ETH_P_ARP / 256;
  	tcp_ctrl -> ether_frame[13] = ETH_P_ARP % 256;

  	// Next is ethernet frame data (ARP header).

  	// ARP header
	memcpy (tcp_ctrl->ether_frame + ETH_HDRLEN, &arphdr, ARP_HDRLEN * sizeof (uint8_t));

	// Send ethernet frame to socket.
  	if ((bytes = sendto (tcp_ctrl->sd, tcp_ctrl->ether_frame, frame_length, 0, (struct sockaddr *) &(tcp_ctrl->device), sizeof (struct sockaddr_ll))) <= 0) {
    		perror ("sendto() failed");
   		 exit (EXIT_FAILURE);
  	}	
	
	printf("Exiting : sd_ARP_rq()\n");
}

void rcv_ARP_asw(struct tcp_ctrl* tcp_ctrl) {
	
	// Listen for incoming ethernet frame from socket sd.
  	// We expect an ARP ethernet frame of the form:
  	//     MAC (6 bytes) + MAC (6 bytes) + ethernet type (2 bytes)
 	//     + ethernet data (ARP header) (28 bytes)
  	// Keep at it until we get an ARP reply.

	printf("Entering : rcv_ARP_asw()\n");

  	int status, i;
  	arp_hdr *arphdr;

  	arphdr = (arp_hdr *) (tcp_ctrl->ether_frame + ETH_HDRLEN);

 	while (((((tcp_ctrl->ether_frame[12]) << 8) + tcp_ctrl->ether_frame[13]) != ETH_P_ARP) || (ntohs(arphdr -> opcode) != ARPOP_REPLY)) {
    		if ((status = recv (tcp_ctrl->sd, tcp_ctrl->ether_frame, IP_MAXPACKET, 0)) < 0) {
      			if (errno == EINTR) {
        			memset (tcp_ctrl->ether_frame, 0, IP_MAXPACKET * sizeof (uint8_t));
      				continue;  // Something weird happened, but let's try again.
      			} else {
        			perror ("recv() failed:");
        			exit (EXIT_FAILURE);
     			}
    		}
  	}

  	for (i = 0; i < 6; i++) tcp_ctrl->dst_mac[i]=arphdr-> sender_mac[i];
 	for (i = 0; i < 6; i++) printf("%02x:", tcp_ctrl->dst_mac[i]);  
 	printf("\n"); 
	

  	// DEBBUG - TO BE COMMENTED
  	// Print out contents of received ethernet frame.
 	/*printf ("\nEthernet frame header:\n");
  	printf ("Destination MAC (this node): ");
  	for (i=0; i<5; i++) {
   		printf ("%02x:", tcp_ctrl->ether_frame[i]);
  	}
  	printf ("%02x\n", tcp_ctrl->ether_frame[5]);
  	printf ("Source MAC: ");
  	for (i=0; i<5; i++) {
   		printf ("%02x:", tcp_ctrl->ether_frame[i+6]);
  	}
  	printf ("%02x\n", tcp_ctrl->ether_frame[11]);

  	// Next is ethernet type code (ETH_P_ARP for ARP).
  	// http://www.iana.org/assignments/ethernet-numbers
  	printf ("Ethernet type code (2054 = ARP): %u\n", ((tcp_ctrl->ether_frame[12]) << 8) + tcp_ctrl->ether_frame[13]);
  	printf ("\nEthernet data (ARP header):\n");
  	printf ("Hardware type (1 = ethernet (10 Mb)): %u\n", ntohs (arphdr->htype));
  	printf ("Protocol type (2048 for IPv4 addresses): %u\n", ntohs (arphdr->ptype));
  	printf ("Hardware (MAC) address length (bytes): %u\n", arphdr->hlen);
  	printf ("Protocol (IPv4) address length (bytes): %u\n", arphdr->plen);
  	printf ("Opcode (2 = ARP reply): %u\n", ntohs (arphdr->opcode));
  	printf ("Sender hardware (MAC) address: ");
  	for (i=0; i<5; i++) {
    		printf ("%02x:", arphdr->sender_mac[i]);
  	}
  	printf ("%02x\n", arphdr->sender_mac[5]);
  	printf ("Sender protocol (IPv4) address: %u.%u.%u.%u\n",
  	arphdr->sender_ip[0], arphdr->sender_ip[1], arphdr->sender_ip[2], arphdr->sender_ip[3]);
  	printf ("Target (this node) hardware (MAC) address: ");
  	for (i=0; i<5; i++) {
  		printf ("%02x:", arphdr->target_mac[i]);
  	}
  	printf ("%02x\n", arphdr->target_mac[5]);
  	printf ("Target (this node) protocol (IPv4) address: %u.%u.%u.%u\n",
  	arphdr->target_ip[0], arphdr->target_ip[1], arphdr->target_ip[2], arphdr->target_ip[3]);
	*/

	//printf("Entering : rcv_ARP_asw()\n");
} 
	
// Allocate memory for an array of chars.
char *allocate_strmem (int len)
{
  void *tmp;

  if (len <= 0) {
    fprintf (stderr, "ERROR: Cannot allocate memory because len = %i in allocate_strmem().\n", len);
    exit (EXIT_FAILURE);
  }

  tmp = (char *) malloc (len * sizeof (char));
  if (tmp != NULL) {
    memset (tmp, 0, len * sizeof (char));
    return (tmp);
  } else {
    fprintf (stderr, "ERROR: Cannot allocate memory for array allocate_strmem().\n");
    exit (EXIT_FAILURE);
  }
}

// Allocate memory for an array of unsigned chars.
uint8_t *allocate_ustrmem (int len)
{
  void *tmp;

  if (len <= 0) {
    fprintf (stderr, "ERROR: Cannot allocate memory because len = %i in allocate_ustrmem().\n", len);
    exit (EXIT_FAILURE);
  }

  tmp = (uint8_t *) malloc (len * sizeof (uint8_t));
  if (tmp != NULL) {
    memset (tmp, 0, len * sizeof (uint8_t));
    return (tmp);
  } else {
    fprintf (stderr, "ERROR: Cannot allocate memory for array allocate_ustrmem().\n");
    exit (EXIT_FAILURE);
  }
}

// Allocate memory for an array of ints.
int *allocate_intmem (int len)
{
  void *tmp;

  if (len <= 0) {
    fprintf (stderr, "ERROR: Cannot allocate memory because len = %i in allocate_intmem().\n", len);
    exit (EXIT_FAILURE);
  }

  tmp = (int *) malloc (len * sizeof (int));
  if (tmp != NULL) {
    memset (tmp, 0, len * sizeof (int));
    return (tmp);
  } else {
    fprintf (stderr, "ERROR: Cannot allocate memory for array allocate_intmem().\n");
    exit (EXIT_FAILURE);
  }
}

// Checksum function
uint16_t checksum (uint16_t *addr, int len)
{
  int nleft = len;
  int sum = 0;
  uint16_t *w = addr;
  uint16_t answer = 0;

  while (nleft > 1) {
    sum += *w++;
    nleft -= sizeof (uint16_t);
  }

  if (nleft == 1) {
    *(uint8_t *) (&answer) = *(uint8_t *) w;
    sum += answer;
  }

  sum = (sum >> 16) + (sum & 0xFFFF);
  sum += (sum >> 16);
  answer = ~sum;
  return (answer);
}

// Build IPv4 TCP pseudo-header and call checksum function.
uint16_t tcp4_checksum (struct ip iphdr, struct tcphdr tcphdr, uint8_t *payload, int payloadlen)
{
  uint16_t svalue;
  char buf[IP_MAXPACKET], cvalue;
  char *ptr;
  int i, chksumlen = 0;

  memset (buf, 0, IP_MAXPACKET);

  ptr = &buf[0];  // ptr points to beginning of buffer buf

  // Copy source IP address into buf (32 bits)
  memcpy (ptr, &iphdr.ip_src.s_addr, sizeof (iphdr.ip_src.s_addr));
  ptr += sizeof (iphdr.ip_src.s_addr);
  chksumlen += sizeof (iphdr.ip_src.s_addr);

  // Copy destination IP address into buf (32 bits)
  memcpy (ptr, &iphdr.ip_dst.s_addr, sizeof (iphdr.ip_dst.s_addr));
  ptr += sizeof (iphdr.ip_dst.s_addr);
  chksumlen += sizeof (iphdr.ip_dst.s_addr);

  // Copy zero field to buf (8 bits)
  *ptr = 0; ptr++;
  chksumlen += 1;

  // Copy transport layer protocol to buf (8 bits)
  memcpy (ptr, &iphdr.ip_p, sizeof (iphdr.ip_p));
  ptr += sizeof (iphdr.ip_p);
  chksumlen += sizeof (iphdr.ip_p);

  // Copy TCP length to buf (16 bits)
  svalue = htons (sizeof (tcphdr) + payloadlen);
  memcpy (ptr, &svalue, sizeof (svalue));
  ptr += sizeof (svalue);
  chksumlen += sizeof (svalue);

  // Copy TCP source port to buf (16 bits)
  memcpy (ptr, &tcphdr.th_sport, sizeof (tcphdr.th_sport));
  ptr += sizeof (tcphdr.th_sport);
  chksumlen += sizeof (tcphdr.th_sport);

  // Copy TCP destination port to buf (16 bits)
  memcpy (ptr, &tcphdr.th_dport, sizeof (tcphdr.th_dport));
  ptr += sizeof (tcphdr.th_dport);
  chksumlen += sizeof (tcphdr.th_dport);

  // Copy sequence number to buf (32 bits)
  memcpy (ptr, &tcphdr.th_seq, sizeof (tcphdr.th_seq));
  ptr += sizeof (tcphdr.th_seq);
  chksumlen += sizeof (tcphdr.th_seq);

  // Copy acknowledgement number to buf (32 bits)
  memcpy (ptr, &tcphdr.th_ack, sizeof (tcphdr.th_ack));
  ptr += sizeof (tcphdr.th_ack);
  chksumlen += sizeof (tcphdr.th_ack);

  // Copy data offset to buf (4 bits) and
  // copy reserved bits to buf (4 bits)
  cvalue = (tcphdr.th_off << 4) + tcphdr.th_x2;
  memcpy (ptr, &cvalue, sizeof (cvalue));
  ptr += sizeof (cvalue);
  chksumlen += sizeof (cvalue);

  // Copy TCP flags to buf (8 bits)
  memcpy (ptr, &tcphdr.th_flags, sizeof (tcphdr.th_flags));
  ptr += sizeof (tcphdr.th_flags);
  chksumlen += sizeof (tcphdr.th_flags);

  // Copy TCP window size to buf (16 bits)
  memcpy (ptr, &tcphdr.th_win, sizeof (tcphdr.th_win));
  ptr += sizeof (tcphdr.th_win);
  chksumlen += sizeof (tcphdr.th_win);

  // Copy TCP checksum to buf (16 bits)
  // Zero, since we don't know it yet
  *ptr = 0; ptr++;
  *ptr = 0; ptr++;
  chksumlen += 2;

  // Copy urgent pointer to buf (16 bits)
  memcpy (ptr, &tcphdr.th_urp, sizeof (tcphdr.th_urp));
  ptr += sizeof (tcphdr.th_urp);
  chksumlen += sizeof (tcphdr.th_urp);

  // Copy payload to buf
  memcpy (ptr, payload, payloadlen);
  ptr += payloadlen;
  chksumlen += payloadlen;

  // Pad to the next 16-bit boundary
  i = 0;
  while (((payloadlen+i)%2) != 0) {
    i++;
    chksumlen++;
    ptr++;
  }

  return checksum ((uint16_t *) buf, chksumlen);
}

// Build IPv4 TCP pseudo-header and call checksum function.
uint16_t
tcp2_checksum (struct ip iphdr, struct tcphdr tcphdr)
{
  uint16_t svalue;
  char buf[IP_MAXPACKET], cvalue;
  char *ptr;
  int chksumlen = 0;

  ptr = &buf[0];  // ptr points to beginning of buffer buf

  // Copy source IP address into buf (32 bits)
  memcpy (ptr, &iphdr.ip_src.s_addr, sizeof (iphdr.ip_src.s_addr));
  ptr += sizeof (iphdr.ip_src.s_addr);
  chksumlen += sizeof (iphdr.ip_src.s_addr);

  // Copy destination IP address into buf (32 bits)
  memcpy (ptr, &iphdr.ip_dst.s_addr, sizeof (iphdr.ip_dst.s_addr));
  ptr += sizeof (iphdr.ip_dst.s_addr);
  chksumlen += sizeof (iphdr.ip_dst.s_addr);

  // Copy zero field to buf (8 bits)
  *ptr = 0; ptr++;
  chksumlen += 1;

  // Copy transport layer protocol to buf (8 bits)
  memcpy (ptr, &iphdr.ip_p, sizeof (iphdr.ip_p));
  ptr += sizeof (iphdr.ip_p);
  chksumlen += sizeof (iphdr.ip_p);

  // Copy TCP length to buf (16 bits)
  svalue = htons (sizeof (tcphdr));
  memcpy (ptr, &svalue, sizeof (svalue));
  ptr += sizeof (svalue);
  chksumlen += sizeof (svalue);

  // Copy TCP source port to buf (16 bits)
  memcpy (ptr, &tcphdr.th_sport, sizeof (tcphdr.th_sport));
  ptr += sizeof (tcphdr.th_sport);
  chksumlen += sizeof (tcphdr.th_sport);

  // Copy TCP destination port to buf (16 bits)
  memcpy (ptr, &tcphdr.th_dport, sizeof (tcphdr.th_dport));
  ptr += sizeof (tcphdr.th_dport);
  chksumlen += sizeof (tcphdr.th_dport);

  // Copy sequence number to buf (32 bits)
  memcpy (ptr, &tcphdr.th_seq, sizeof (tcphdr.th_seq));
  ptr += sizeof (tcphdr.th_seq);
  chksumlen += sizeof (tcphdr.th_seq);

  // Copy acknowledgement number to buf (32 bits)
  memcpy (ptr, &tcphdr.th_ack, sizeof (tcphdr.th_ack));
  ptr += sizeof (tcphdr.th_ack);
  chksumlen += sizeof (tcphdr.th_ack);

  // Copy data offset to buf (4 bits) and
  // copy reserved bits to buf (4 bits)
  cvalue = (tcphdr.th_off << 4) + tcphdr.th_x2;
  memcpy (ptr, &cvalue, sizeof (cvalue));
  ptr += sizeof (cvalue);
  chksumlen += sizeof (cvalue);

  // Copy TCP flags to buf (8 bits)
  memcpy (ptr, &tcphdr.th_flags, sizeof (tcphdr.th_flags));
  ptr += sizeof (tcphdr.th_flags);
  chksumlen += sizeof (tcphdr.th_flags);

  // Copy TCP window size to buf (16 bits)
  memcpy (ptr, &tcphdr.th_win, sizeof (tcphdr.th_win));
  ptr += sizeof (tcphdr.th_win);
  chksumlen += sizeof (tcphdr.th_win);

  // Copy TCP checksum to buf (16 bits)
  // Zero, since we don't know it yet
  *ptr = 0; ptr++;
  *ptr = 0; ptr++;
  chksumlen += 2;

  // Copy urgent pointer to buf (16 bits)
  memcpy (ptr, &tcphdr.th_urp, sizeof (tcphdr.th_urp));
  ptr += sizeof (tcphdr.th_urp);
  chksumlen += sizeof (tcphdr.th_urp);

  return checksum ((uint16_t *) buf, chksumlen);
}
