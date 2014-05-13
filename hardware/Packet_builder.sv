/*Want to create a full packet, which is the Ethernet, IP, and TCP headers combined */

module Packet_builder( 	input logic         clk,
	      		input logic         rst,
	      		output logic [4:0] ethernet_control_bit, /*increments by 1 each load*/
	      		input logic  [7:0]  id_in,	
	      		output logic [31:0] packet_buffer);

	//for RAM reads
	logic [8:0] addr;
	logic [31:0] ram_in;
	logic [31:0] ram_out;
	logic wren;
	logic [8:0] empty;

	logic [508:0] packet; /*Need to add on payload still..*/
	logic [256:0] RAM_stored_header_data; /*stores the 32 (32x8 bits) bytes of 1 record*/

	RAM2 connection_RAM (.address (addr[7:0]), .clock (clk), .data(ram_in), .wren(wren), .q(ram_out));

	/*These logic loads the data saved from RAM into RAM_stored_header_data*/
	enum logic [1:0] {idle, continue_one, continue_two, continue_three, continue_four, continue_five, continue_six, continue_seven, done} current_state;

/*****************THIS PORTION OF THE CODE GATHERS DATA FROM THE RAM**************************************************/

always_ff @ (posedge clk) 
	begin
	if(id_in==7'b0) //address
		begin
		current_state <= idle;
		RAM_stored_header_data <= 256'b0;
		ethernet_control_bit <= 4'b0; /*Control bits for the toe_init*/
		end
	 else if(current_state==done)
		begin						
		current_state <= idle;
	        end
	 else
		begin
					case(id_in)
					   	begin
						    7'b0: if(current_state==idle && rst) /*rst??*/
								begin
								   RAM_stored_header_data[256:224] <= ram_out[31:0]; /*This is the valid bit--check at start of next case*/					
								   current_state <= continue_one;			
								   //ethernet_control_bit = 4'b1;	
								end			
						    7'b1: if(current_state==continue_one)
							begin
									if(RAM_stored_header_data[256]==1'b1) /*The valid bit is set high, so continue with operation*/
								          begin
									        RAM_stored_header_data[223:192] <= ram_out[31:0]; /*seq*/
										current_state <= continue_two;	
										//ethernet_control_bit = 4'b2;	
								          end
									else begin
								    	 current_state <= idle;
							      	     	     end
							end
						    7'b2: if(current_state==continue_two)
							begin
								RAM_stored_header_data[191:160] <= ram_out[31:0]; /*ack*/
								current_state <= continue_three;
								//ethernet_control_bit = 4'b3;	
							end
						    7'b3: if(current_state==continue_three)
							begin
								RAM_stored_header_data[159:128] <= ram_out[31:0];  /*ip_src*/
								//ethernet_control_bit = 4'b4;	
							end
						    7'b4: if(current_state==continue_four)
							begin
								RAM_stored_header_data[127:96] <= ram_out[31:0]; /*ip_dst*/
								current_state <= continue_five;
								
							end
						    7'b5: if(current_state==continue_five)
							begin
								RAM_stored_header_data[95:64] <= ram_out[31:0]; /*mac_src*/
								current_state <= continue_six;	
							end
						    7'b6: if(current_state==continue_six)
							begin
								RAM_stored_header_data[63:32] <= ram_out[31:0]; /*mac_dst*/
								current_state <= continue_seven;	
							end
						    7'b87: if(current_state==continue_seven)
							begin
								RAM_stored_header_data[31:0] <= ram_out[31:0]; /*src_port + dst_port*/
								current_state <= done;
							end
					endcase	
			end
	end


/*****************THIS PORTION OF THE CODE MAKES THE PACKET**************************************************/
//-------Ethernet Header Fields----
	//reg [47:0] eth_dst;
	//reg [47:0] eth_src;
	//reg [15:0] eth_type;
	
	
	//-------IP Header Files---------- 
	//reg [3:0] ip_ver;
	//reg [3:0] ip_hlen;
	//reg [7:0] ip_tos;
	//reg [15:0] ip_len;
	//reg [15:0] ip_id;
	//reg [15:0] ip_flag_frag_off; 
	//reg [7:0] ip_ttl;
	//reg [7:0] ip_protocol;
	//reg [15:0] ip_checksum;
	//reg [31:0] ip_src_addr;
	//reg [31:0] ip_dst_addr;
	//reg [31:0] ip_options;
	
	
	//-------TCP Header Files---------- 
	//reg [31:0] tcp_src_port_opt;
	//reg [31:0] tcp_dst_port;
	//reg [31:0] tcp_seq_num;  
	//reg [15:0] tcp_len;
	//reg [15:0] tcp_checksum_opt;
	//reg [3:0] tcp_offset;
	//reg [15:0] tcp_windowsize;
	//reg [31:0] tcp_ack;
	//reg[3:0] tcp_reserved;
	//reg[3:0] tcp_flag; //size of 8
	//reg[15:0] tcp_pointer;

/*Begin parsing and placing values into packet*/
always_comb
   begin
	if(done && RAM_stored_header_data!=256'b0)
		begin
			//packet[508:460]<={}; //eth_dst: 48 bits
			packet[508:460]<=RAM_stored_header_data[63:32] ; //mac_dst ????
			//packet[459:412]<={}; //eth_src: 48 bits
			packet[459:412]<=RAM_stored_header_data[95:64] ; //mac_src ????
			packet[411:396]<={}; //eth_type: 16 bits

			packet[395:392]<={}; //ip_ver: 4 bits
			packet[391:388]<={}; //ip_hlen: 4 bits
			packet[387:380]<={}; //ip_tos: 8 bits
			packet[379:364]<={}; //ip_len: 16 bits
			packet[363:348]<={}; //ip_id: 16 bits
			packet[347:332]<={}; //ip_flag_frag_off: 16 bits
			packet[331:324]<={}; //ip_ttl: 8 bits
			packet[323:316]<={}; //ip_protocol: 8 bits
			packet[315:300]<={}; //ip_checksum: 16 bits
			//packet[299:268]<={}; //ip_src_addr: 32 bits
			packet[299:268] <= RAM_stored_header_data[159:128];//ip_src_addr: 32 bits
			//packet[267:236] <= {}; //ip_dst_addr: 32 bits
			packet[267:236] <= RAM_stored_header_data[127:96];//ip_dst_addr: 32 bits 
			packet[235:204]<={}; //ip_options: 32 bits

			//packet[203:172]<={}; //tcp_src_ports: 32 bits
			packet[203:172]<=RAM_stored_header_data[31:0]; //srcport 
			packet[171:140]<={}; //tcp_dst_ports: 32 bits
			packet[203:172]<=RAM_stored_header_data[31:0]; //dstport
			//packet[139:108]<={}; //tcp_seq_num: 32 bits
			packet[139:108] <= RAM_stored_header_data[223:192];  	//tcp_seq_num: 32 bits	
			packet[107:92]<={}; //tcp_len: 16 bits
			packet[91:76]<={}; //tcp_checksum: 16 bits
			packet[75:72]<={}; //tcp_offset: 4 bits
			packet[71:56]<={};//tcp windowsize: 16 bits
			//packet[55:24]<={}; //tcp_ack: 32 bits
			packet[55:24] <= RAM_stored_header_data[191:160]; //tcp_ack: 32 bits
			packet[23:20]<={}; //tcpreserved: 4 bits
			packet[19:16]<={}; //tcpflag 4 bits
			packet[15:0]<={}; //tcppointer 16 bits

			//packet[]<=RAM_stored_header_data[];
		end
   end

endmodule
