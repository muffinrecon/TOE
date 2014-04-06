#include "tcp.h"

int main(int argc, char **argv) {
	int status;
	printf("Starting Main \n");
	struct tcp_ctrl *tcp_ctrl = tcp_new();
	if ((status = tcp_bind(tcp_ctrl, "209.2.233.147", 52000, "wlan0")) < 0){
		perror("Couldn't bind socket to port\n");
		exit(EXIT_FAILURE); 
	} 
	if ((status = tcp_connect(tcp_ctrl, "www.google.com")) < 0) {
		perror("Couldn't connect to server\n");
		exit(EXIT_FAILURE);
	}
	
	printf("**************** HANDSHAKE COMPLETED ***********************\n");
	
	char *data = "GET / HTTP/1.0\r\n\r\n";
	tcp_write(tcp_ctrl, data, strlen(data));

	printf("**************** DATA TRANSMISSION COMPLETED ***************\n");
	
	return 0;
}


