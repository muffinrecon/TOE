#include "tcp.h"

int main(int argc, char **argv) {
	int status;
	FILE *fi;

	printf("Starting Main \n");
	struct tcp_ctrl *tcp_ctrl = tcp_new();
	if ((status = tcp_bind(tcp_ctrl, "209.2.233.2", 52000, "wlan0")) < 0){
		perror("Couldn't bind socket to port\n");
		exit(EXIT_FAILURE); 
	} 
	if ((status = tcp_connect(tcp_ctrl, "www.google.com")) < 0) {
		perror("Couldn't connect to server\n");
		exit(EXIT_FAILURE);
	}
	
	printf("**************** HANDSHAKE COMPLETED ***********************\n");
	
	char *data_ptr = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789aabbccddeeffgghhiijjkklloommnnppqqrrssttuuvvwwxxyyzzAABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWXXYYZZ00112233445566778899aaabbbcccdddeeefffggghhhiiijjjkkklllmmmnnnooopppqqqrrrssstttuuuvvvwwwxxxyyyzzzAAABBBCCCDDDEEEFFFGGGHHHIIIJJJKKKLLLMMMNNNOOOPPPQQQRRRSSSTTTUUUVVVWWWXXXYYYZZZ000111222333444555666777888999";


	tcp_write(tcp_ctrl, data_ptr, strlen(data_ptr));

	printf("**************** DATA TRANSMISSION COMPLETED ***************\n");
	
	return 0;
}


