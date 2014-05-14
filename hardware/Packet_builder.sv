/*Want to create a full packet, which is the Ethernet, IP, and TCP headers combined */

module Packet_builder( input logic [8:0] addr,
							  input logic [31:0] ram_in,
							  output logic [31:0] ram_out,
							  input logic wren,
							  input logic [8:0] empty);

	//for RAM reads
	logic [8:0] addr;
	logic [31:0] ram_in;
	logic [31:0] ram_out;
	logic wren;
	logic [8:0] empty;

	logic [475:0] packet; /*Need to add on payload still..*/
	logic [287:0] RAM_stored_header_data; /*stores the 32 (32x9 bits) bytes of 1 record*/
	
	logic last_record;
	assign last_record =  (base_addr == 8'd224); 

	//will instantiate within the TOE (but right now RAM?)-> values are passed into PB
	//RAM2 connection_RAM (.address (addr[7:0]), .clock (clk), .data(ram_in), .wren(wren), .q(ram_out));
	
	/* States of the high-level automata */ 
	enum logic [1:0] {hl_IDLE, hl_SEARCHING, hl_CHECKING} hl_state; 

	/*States of second-level automata */
	enum logic [4:0] {idle, continue_one, continue_two, continue_three, continue_four, continue_five, continue_six, continue_seven, continue_eight, done} current_state;

/*****************THIS PORTION OF THE CODE GATHERS DATA FROM THE RAM**************************************************/

	logic [7:0] 	base_addr;

always_comb
	begin
		base_addr=7'd0;
		case(current_state)
			begin
			idle: addr=base_addr;
			continue_one: addr=base_addr+7'd1;
			continue_two: addr=base_addr+7'd2;
			continue_three: addr=base_addr+7'd3;
			continue_four: addr=base_addr+7'd4;
			continue_five: addr=base_addr+7'd5;
			continue_six: addr=base_addr+7'd6;
			continue_seven: addr=base_addr+7'd7;
			default:addr=base_addr;
			end
		endcase
	end
	
	logic valid_bit_high;
	/*for the purpose of checking just valid*/
always_ff@(posedge clk)
	begin
		case (hl_state) 
			hl_IDLE : 
				begin 
					case (req) 
						2'b01   :  hl_state <= hl_SEARCHING;
						2'b10   :  hl_state <= hl_CHECKING;
						default :  hl_state <= hl_IDLE;
					endcase
					valid_bit_high <=1'b0;
				end 
			h1_searching:
				begin
				RAM_stored_header_data[286:255] <=ram_out[31:0]; /*Grabbing just the valid bit*/
				end
			hl_checking:
				begin
				if(RAM_stored_header_data[286]==1'b1) /*The valid bit is set high, so continue with operation*/
					begin
					valid_bit_high=1'b1;
					end
		endcase
	end
	
	/*triggered by valid_bit_high*/
always_ff @ (posedge clk) 
	begin
	if(valid_bit_high) //address
		begin
		current_state <= idle;
		RAM_stored_header_data <= 287'b0;
		end
	 else if(current_state==done)
		begin						
		current_state <= idle;
	        end
	 else
		begin
					case(current_state)
					   	idle:
								begin
								   RAM_stored_header_data[287:256] <= ram_out[31:0]; /*This is the valid bit--check at start of next case*/					
								   current_state <= continue_one;			
								end			
						    continue_one:
								begin
									RAM_stored_header_data[255:224] <= ram_out[31:0]; /*seq*/
									current_state <= continue_two;	
								end
						    continue_two:
								begin
								RAM_stored_header_data[223:192] <= ram_out[31:0]; /*ack*/
								current_state <= continue_three;
								end
						    continue_three: 
								begin
									RAM_stored_header_data[191:160] <= ram_out[31:0];  /*ip_src*/
									current_state <= continue_four;
								end
							 continue_four: 
								begin
									RAM_stored_header_data[159:128] <= ram_out[31:0]; /*ip_dst*/
									current_state <= continue_five;
								end
						    continue_five: 
								begin
									RAM_stored_header_data[127:96] <= ram_out[31:0]; /*mac_src*/
									current_state <= continue_six;	
								end
							 continue_six:
								begin
									RAM_stored_header_data[95:64] <= ram_out[31:0]; /*half mac_dst and half mac_src*/
									current_state <= continue_seven;	
								end
						    continue_seven: 
									begin
									RAM_stored_header_data[63:32] <= ram_out[31:0]; /*mac_dst*/
									current_state <= continue_eight;	
									end
								end
						    continue_eight: 
									begin
									RAM_stored_header_data[31:0] <= ram_out[31:0]; /*src_port + dst_port*/
									current_state <= done;
									end
					endcase	
			end
	end


/*****************THIS PORTION OF THE CODE MAKES THE PACKET**************************************************/


/*Begin parsing and placing values into packet*/
always_comb
   begin
	if(current_state==done && RAM_stored_header_data!=287'b0)
		begin
			/*-------Ethernet Header Fields----*/
		
			packet[475:428]<=RAM_stored_header_data[63:32] ; //mac_dst 48 bit
			packet[427:380]<=RAM_stored_header_data[95:64] ; //mac_src 48 bit
			packet[379:364]<=16'b0; //eth_type: 16 bits

			/*-------IP Header Files----------*/
			packet[363:360]<=4'b0; //ip_ver: 4 bits
			packet[359:356]<=4'b0; //ip_hlen: 4 bits
			packet[355:348]<=8'b0; //ip_tos: 8 bits
			packet[347:332]<=16'b0; //ip_len: 16 bits
			packet[331:316]<=16'b0; //ip_id: 16 bits
			packet[315:300]<=16'b0; //ip_flag_frag_off: 16 bits
			packet[299:292]<=8'b0; //ip_ttl: 8 bits
			packet[291:284]<=8'b0; //ip_protocol: 8 bits
			packet[283:268]<=16'b0; //ip_checksum: 16 bits
			packet[267:236] <= RAM_stored_header_data[159:128];//ip_src_addr: 32 bits
			packet[235:204] <= RAM_stored_header_data[127:96];//ip_dst_addr: 32 bits 
			packet[203:172]<=32'b0; //ip_options: 32 bits

			/*-------TCP Header Files----------*/
			packet[171:156]<=RAM_stored_header_data[15:0]; //srcport 
			packet[155:140]<=RAM_stored_header_data[31:16]; //dstport
			packet[139:108] <= RAM_stored_header_data[223:192];  	//tcp_seq_num: 32 bits	
			packet[107:92]<=16'b0; //tcp_len: 16 bits
			packet[91:76]<=16'b0; //tcp_checksum: 16 bits
			packet[75:72]<=4'b0; //tcp_offset: 4 bits
			packet[71:56]<=16'b0;//tcp windowsize: 16 bits
			packet[55:24] <= RAM_stored_header_data[191:160]; //tcp_ack: 32 bits
			packet[23:20]<=4'b0; //tcpreserved: 4 bits
			packet[19:16]<=4'b0; //tcpflag 4 bits
			packet[15:0]<=16'b0;//tcppointer 16 bits
		end
	end
   

endmodule
