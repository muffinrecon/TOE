#include "tcp.h"

int tcp_set_rawsck(void) {
	tcp_new = tcp_new_rawsck;
	tcp_bind = tcp_bind_rawsck;
	tcp_connect = tcp_connect_rawsck;
	tcp_write = tcp_write_rawsck;
	tcp_rcv = tcp_rcv_rawsck;
 	tcp_close = tcp_close_rawsck;
	return 0;
}
