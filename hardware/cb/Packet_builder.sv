/* Creates a complete packet made of payload and header */
// This module may need to be splitted in several smaller modules  
// checksums will be handled by downstream module 

// Length of the header is 54 bytes = 432 bits since TCP options are not used 

module Packet_builder(	input logic 		clk,
		 	input logic 		rst,
			output logic [7:0] 	addr,
			output logic [31:0] 	ram_in,
			input logic [31:0] 	ram_out,
			output logic 		wren,
			output logic [431:0] 	header, //add payload
			output logic 		ready,
			input logic 		busy); 

	parameter TCP_SENT_SYN = 31'd2;
	parameter TCP_CLOSED = 31'd1;

	enum logic [1:0] {s_IDLE, s_REQ, s_WAIT, s_CHECK} s_state;
	enum logic [4:0] {o_IDLE, o_REQ, o_WAIT, o_CPY_SEQ, o_CPY_ACK, 
				o_CPY_IP_SRC, o_CPY_IP_DST, o_CPY_MAC_DST1,
				o_CPY_MAC_DST2, o_CPY_MAC_SRC1, o_CPY_MAC_SRC2, o_CPY_PORTS, o_STALL, o_DONE} o_state;  

	logic 		found_closed;
	enum logic {g_SEARCH, g_OPENING_CONNECTION} g_state;
	logic [7:0] 	base_addr;
	logic 		last_record;	
	
	assign ready = (o_state == o_DONE); 
	assign last_record =  (base_addr == 8'd240); 

	
	
	always_ff@ (posedge clk)
		begin
		if (rst) g_state <= g_SEARCH;
		else 
			case (g_state) 
				g_SEARCH :
					begin  
					if (found_closed) g_state <= g_OPENING_CONNECTION;
					else g_state <= g_SEARCH;
					end
				g_OPENING_CONNECTION : 
					begin
					if (ready) g_state <= g_SEARCH;
					else g_state <= g_OPENING_CONNECTION;
					end
			endcase 
		end

	always_ff@ (posedge clk)
		begin
		if (rst)
			begin  
			s_state <= s_REQ;
			base_addr <= 8'd0;
			found_closed <= 1'b1;
			end
		if (g_state == g_SEARCH) 
			case (s_state) 
				s_IDLE	 : 
					begin	
					s_state <= s_REQ; 
					found_closed <= 1'b0;
					end
				s_REQ	 :
					begin 
					s_state <= s_WAIT; 
					end 
				s_WAIT	 : s_state <= s_CHECK; 
				s_CHECK	 :
					begin 
					if ((ram_out[31] == 1'b1) && (ram_out[30:0] == TCP_CLOSED)) 
						begin
						found_closed <= 1'b1;
						s_state <= s_IDLE;
						end 	
					else 
						begin
						s_state <= s_REQ;
						if (last_record) base_addr <= 8'd0;
						else base_addr <= base_addr + 8'd10;
						end
					end	     
			endcase
		else s_state <= s_IDLE; 
		end		


	
	always_ff@ (posedge clk) 
		begin
		if (rst) 
			begin
			o_state <= o_IDLE;
			header <= 432'd0; 
			end
		else if (g_state == g_OPENING_CONNECTION)
			case (o_state) 
				o_IDLE		: o_state <= o_REQ;
				o_REQ 		: o_state <= o_WAIT;  
				o_WAIT		: 
					begin
					o_state <= o_CPY_SEQ;
					
					//[431:384] and [383:336] are used for dst and src mac addresses  

					/* **** ETH **** */
					header[335:320] <= 16'h0080; //eth_type : IP

					/* **** IP **** */ 
					header[319:316] <= 4'h4;  	//ip_ver = 4
					header[315:312] <= 4'h5;  	//ip_hlen = 20 bytes (5 words)
					header[311:304] <= 8'h10;  	//ip_tos
					header[303:288] <= 16'h0000; 	//ip_len FILLED AFTERWARD
					header[287:272] <= 16'h0000; 	//ip_id
					header[271:269] <= 3'h02;	//ip_flag = don't fragment
					header[268:256] <= 13'h0000; 	//frag_off
					header[255:248] <= 8'h40;  	//ip_ttl
					header[247:240] <= 8'h06; 	//ip_protocol : TCP (06)
					header[239:224] <= 16'h0000; 	//ip_checksum FILLED AFTERWARD 
					//[223:192] and [191:160] are used for source ip and dst ip
				
					/* **** TCP **** */
					// [159:144] and [143:128] are used for dsp port and source port
					// [127:96] is for sequence number
					// [95:64] is used for ACK when flag ACK is set
					header[63:60]  <= 4'h8; 	 //tcp_data_offset
					header[59:57]  <= 3'b000; 	 //tcp_reserved 
					header[56:48]  <= 9'h002; 	 //tcp_flag
					header[47:32]  <= 16'h0000; 	 //tcp_checksum
					header[31:16]  <= 16'h3908;	 //tcp_windowsize
					header[15:0]   <= 16'h0000; 	 //tcp_urgent pointer 
					end 
				o_CPY_SEQ 	: 
					begin
					o_state <= o_CPY_ACK;
					header[127:96] <= ram_out; 	
					end 
				o_CPY_ACK	: 	
					begin
					o_state <= o_CPY_IP_SRC;
					if (header[52] == 1'b1) header[95:64] <= ram_out;  //ACK is enabled
					else header[95:64] <= 32'b0;
					end
				o_CPY_IP_SRC  	: 
					begin
					o_state <= o_CPY_IP_DST;
					header[223:192] <= ram_out;
					end
				o_CPY_IP_DST	: 
					begin
					o_state <= o_CPY_MAC_SRC1;
					header[191:160] <= ram_out;
					end
				o_CPY_MAC_SRC1	: 
					begin
					o_state <= o_CPY_MAC_SRC2;
					header[383:352] <= ram_out;
					end
				o_CPY_MAC_SRC2	: 
					begin
					o_state <= o_CPY_MAC_DST1;
					header[351:336] <= ram_out[31:16];
					end
				o_CPY_MAC_DST1 	: 
					begin
					o_state <= o_CPY_MAC_DST2;
					header[431:400] <= ram_out;
					end
				o_CPY_MAC_DST2 	: 
					begin
					o_state <= o_CPY_PORTS;
					header[399:384] <= ram_out[31:16];
					end
				o_CPY_PORTS 	: 
					begin
					if (busy) o_state <= o_STALL; 
					else o_state <= o_DONE;
					header[159:128] <= ram_out;
					end
				o_STALL :
					begin 
					if (busy) o_state <= o_STALL;
					else o_state <= o_DONE;
					end
				o_DONE	: o_state <= o_IDLE;	
				default	: o_state <= o_IDLE;
			endcase
		end

	// Define behaviour of addr 	
	always_comb
		begin
		if (g_state == g_OPENING_CONNECTION) 
			case (o_state) 
				o_IDLE     	: addr = base_addr;
				o_REQ      	: addr = base_addr; 
				o_WAIT	   	: addr = base_addr + 8'd1; 
				o_CPY_SEQ 	: addr = base_addr + 8'd2;
				o_CPY_ACK	: addr = base_addr + 8'd3;
				o_CPY_IP_SRC 	: addr = base_addr + 8'd4;
				o_CPY_IP_DST 	: addr = base_addr + 8'd5; 
				o_CPY_MAC_SRC1  : addr = base_addr + 8'd6;
				o_CPY_MAC_SRC2  : addr = base_addr + 8'd7;
				o_CPY_MAC_DST1  : addr = base_addr + 8'd8;
				o_CPY_MAC_DST2  : addr = base_addr;
				o_CPY_PORTS	: addr = base_addr;
				o_STALL		: addr = base_addr;
				o_DONE		: addr = base_addr;
			endcase
		else addr = base_addr;
		end 

	assign wren = (o_state == o_DONE);
	assign ram_in = {1'b1, TCP_SENT_SYN};

endmodule 
		
