#include "tcp.h"

int main(int argc, char **argv) {
	int status;
	printf("Starting Main \n");
	struct tcp_pcb *tcp_pcb = tcp_new();
	if ((status = tcp_bind(tcp_pcb, "209.2.233.150", 52000, "wlan0")) < 0){
		perror("Couldn't bind socket to port\n");
		exit(EXIT_FAILURE); 
	} 
	if ((status = tcp_connect(tcp_pcb, "www.google.com")) < 0) {
		perror("Couldn't connect to server\n");
		exit(EXIT_FAILURE);
	}
	
	printf("**************** HANDSHAKE COMPLETED ***********************");	
	return 0;
}


