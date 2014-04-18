#include "tcp.h"

#define RCP_BUFFER 100000

int main(int argc, char **argv) {
	int status;

	uint8_t *rcv_data = (uint8_t *) malloc(RCP_BUFFER*sizeof(uint8_t));  
	if (rcv_data == NULL) printf("ERROR ALLOCATING RECEPTION BUFFER\n"); 
	else printf("allocation worked\n");

	struct tcp_ctrl *tcp_ctrl = tcp_new();
	if ((status = tcp_bind(tcp_ctrl, "209.2.232.216", 52000, "wlan0")) < 0){
		perror("Couldn't bind socket to port\n");
		exit(EXIT_FAILURE); 
	} 
	if ((status = tcp_connect(tcp_ctrl, "www.google.com")) < 0) {
		perror("Couldn't connect to server\n");
		exit(EXIT_FAILURE);
	}
	printf("**************** HANDSHAKE COMPLETED ***********************\n");
	
	char *sd_data1 = "GET / HTTP/1.1\r\n\r\n";
	tcp_write(tcp_ctrl, sd_data1, strlen(sd_data1));
	printf("**************** REQUEST COMPLETED ***************\n");
	
	tcp_rcv(tcp_ctrl, rcv_data, RCP_BUFFER);
	printf("**************** TRANSMISSION COMPLETED ***************\n");
	
	printf("Request : %s\n", (char *) rcv_data); 
        		
	free(rcv_data);
	return 0;
}
