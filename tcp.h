#include "tcp_rawsck.h"

struct tcp_ctrl *(*tcp_new)(void);
int (*tcp_bind)(struct tcp_ctrl*, char*, uint16_t, char*);
int (*tcp_connect)(struct tcp_ctrl *, char *);
struct tcp_ctrl *(*tcp_listen)(struct tcp_ctrl *);
void (*tcp_accept)(struct tcp_ctrl *);
int (*tcp_write)(struct tcp_ctrl *, void *, int);
int (*tcp_rcv)(struct tcp_ctrl *, uint8_t *, int);
int (*tcp_close)(struct tcp_ctrl *);

int tcp_set_rawsck(void);
//int tcp_set_hw(void);
