#include "tcp.h"

int main(int argc, char **argv) {
	int status;
	FILE *fi;

	printf("Starting Main \n");
	struct tcp_ctrl *tcp_ctrl = tcp_new();
	if ((status = tcp_bind(tcp_ctrl, "209.2.232.222", 52000, "wlan0")) < 0){
		perror("Couldn't bind socket to port\n");
		exit(EXIT_FAILURE); 
	} 
	if ((status = tcp_connect(tcp_ctrl, "www.google.com")) < 0) {
		perror("Couldn't connect to server\n");
		exit(EXIT_FAILURE);
	}
	
	printf("**************** HANDSHAKE COMPLETED ***********************\n");
	
	fi = fopen("data", "r");
	char *data_ptr = malloc(20000 * sizeof(uint8_t));
	int i = 0;
	char c;
	while((c = fgetc(fi)) != EOF){
		data_ptr[i] = c;
		i++;
	} 
	

	tcp_write(tcp_ctrl, data_ptr, i);

	printf("**************** DATA TRANSMISSION COMPLETED ***************\n");
	
	return 0;
}
