#define ARP_HDRLEN 28 // ARP header length
#define ARPOP_REQUEST 1 // Taken from <linux/if_arp.h>
#define ARPOP_REPLY 2


typedef struct _arp_hdr arp_hdr;

struct _arp_hdr {
  uint16_t htype;
  uint16_t ptype;
  uint8_t hlen;
  uint8_t plen;
  uint16_t opcode;
  uint8_t sender_mac[6];
  uint8_t sender_ip[4];
  uint8_t target_mac[6];
  uint8_t target_ip[4];
};
