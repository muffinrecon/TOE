`timescale 1 ns / 100 ps



module packetizer(data_in,clk, reset_n, start_packet, end_packet, EN, writeReq, reset, done, data_out, ethernet_header_data, ip_header_data, tcp_header_data, ready);
	
	parameter START = 4'b0000;
	parameter DROP_PACKET = 4'b0001;
	parameter PREAMBLE = 4'b0010;
	parameter ETH_MAC = 4'b0011;
	parameter ETH_SRC_MAC = 4'b0100;
	parameter ETH_VLAN = 4'b0101;
	parameter IP_HDR_S1 = 4'b0110;
	parameter IP_HDR_S2 = 4'b0111;
	parameter IP_HDR_OPT = 4'b1000;
	parameter TCP_HDR_S1 = 4'b1001;
	parameter TCP_ACK_S1 = 4'b1010;
	parameter RESERVED = 4'b1011;
	parameter CHECKSUM =  4'b1100;
	parameter PAYLOAD = 4'b1101;
	parameter DONE = 4'b1110;
	
	parameter INPUT_WIDTH = 64;
	parameter BIT_WIDTH = 48; 
	
	input wire [63:0] data_in;
	input wire clk;
	input wire reset_n;
	input wire start_packet;
	input  wire end_packet; 
	input wire EN;
	output wire ready;
	output reg writeReq; 
	output reg reset; 
	output reg done;
	output wire [63:0] data_out;
	output reg [111:0] ethernet_header_data;
	output reg [191:0] ip_header_data;
	output reg [155:0] tcp_header_data;
	
	
	//-------Ethernet Header Fields----
	reg [47:0] eth_dst;
	reg [47:0] eth_src;
	reg [15:0] eth_type;
	
	
	//-------IP Header Files---------- 
	reg [3:0] ip_ver;
	reg [3:0] ip_hlen;
	reg [7:0] ip_tos;
	reg [15:0] ip_len;
	reg [15:0] ip_id;
	reg [15:0] ip_flag_frag_off; 
	reg [7:0] ip_ttl;
	reg [7:0] ip_protocol;
	reg [15:0] ip_checksum;
	reg [31:0] ip_src_addr;
	reg [31:0] ip_dst_addr;
	reg [31:0] ip_options;
	
	
	//-------TCP Header Files---------- 
	reg [15:0] tcp_src_port_opt;
	reg [15:0] tcp_dst_port;
	reg [31:0] tcp_seq_num;  
	reg [15:0] tcp_len;
	reg [15:0] tcp_checksum_opt;
	reg [3:0] tcp_offset;
	reg [15:0] tcp_windowsize;
	reg [31:0] tcp_ack;
	reg[3:0] tcp_reserved;
	reg[3:0] tcp_flag; //size of 8
	reg[15:0] tcp_pointer;
	
	//--------other buses and regs----
	reg [63:0] payload_data;
	reg [63:0] previous_data0;
	reg [63:0] previous_data1;
	reg [63:0] previous_data2;
	reg [63:0] data_aligned;
	reg [15:0] payload_len;
	reg [3:0] offset = 4'b00_00;
	
	
	reg [3:0] next_state;
	wire [3:0] state; 
	reg flag;
	reg done_final;
	reg write_delay;
	reg packet_ended;
	reg [63:0] packet_count = 0;
	
	initial begin 
	offset = 4'b00_00;
	
	end
	
	assign ready = 1'b1;

	//need to look at
	always @ (*)  begin 
		if (offset == 0) begin
			data_aligned = data_in;
		end
		else if (offset == 2) begin 
			data_aligned [63:48] = previous_data0 [15:0];
			data_aligned [47:0] = data_in[63:16];
		end
		else if (offset == 4) begin
			data_aligned [63:32] = previous_data0 [31:0];
			data_aligned [47:0] = data_in[63:32];
		end
		else if (offset == 6) begin 
			data_aligned [63:16] = previous_data0 [47:0];
			data_aligned [15:0] = data_in[63:48];
		end
		else if (offset == 10) begin 
			data_aligned [63:48] = previous_data0 [15:0];
			data_aligned [47:0] = data_in[63:16];
		end
		else if (offset == 14) begin 
			data_aligned [63:16] = previous_data0 [47:0];
			data_aligned [15:0] = data_in[63:48];
		end
		else begin
			data_aligned = data_in;
		end
	end
	

	assign state = next_state;	
	assign data_out = payload_data;
	//an ack?
	
	
	always @ (posedge clk) begin
		if (!reset_n) begin
			//data_out <= 'b0;
			payload_data <= 'b0;
			done <= 'b0;
		end else begin
		ethernet_header_data <= {eth_dst, eth_src, eth_type};
		ip_header_data <= {ip_ver,ip_hlen,ip_tos,ip_len,ip_id,ip_flag_frag_off,ip_ttl,ip_checksum,ip_protocol,ip_src_addr,ip_dst_addr,ip_options};
		tcp_header_data <= {tcp_src_port_opt,tcp_dst_port,tcp_seq_num,tcp_ack,tcp_offset,tcp_reserved,tcp_flag,tcp_windowsize,tcp_checksum_opt,tcp_pointer};
		//data_out <= payload_data;
		
		//if ((delay == 0) || (delay ==1))begin
			//data_in_delay <= data_in;
			//data_in_mid <= data_in_delay;
		//end
		//else if ((delay >1)&&((delay%2) == 1) )begin
		//	if (chill == 0)begin	
		//		chill <= 1;
		//	end
		//	else if (chill == 1)begin
		//		data_in_mid <= data_in_delay;
		//	end
		//end
		//else if ((delay >1)&&((delay%2) == 0) )begin
		//	data_in_delay <= data_in; 
		//	chill <= 0;
	//	end
	
		if (EN) begin
			previous_data0<=data_in;// data variable changed // 7/19
			previous_data1<=previous_data0;
			previous_data2<=previous_data1;
		end
	
		
		
		case (state)
			START: begin
				done <= 1'b0;
				if (EN) begin
					if (start_packet)begin
						packet_count <= packet_count + 1;
						packet_ended <= 1'b0;
						next_state <= ETH_SRC_MAC;
						offset <= 4'b0000;
						//flag <=1;
				eth_dst <= data_in [INPUT_WIDTH-1 : INPUT_WIDTH-48];// data variable changed // 7/19
				eth_src [BIT_WIDTH -1 : BIT_WIDTH-16] <= data_in [INPUT_WIDTH-49 :0 ];// data variable changed // 7/19
				next_state <= ETH_SRC_MAC; 
					end 
					else begin
						next_state <= START; 
						done <=1'b0;
					end
				end
				else begin
					next_state <= START;
				end
			end
			ETH_MAC: begin //3
				
			end
			ETH_SRC_MAC: begin //4
				if (EN) begin
					done <= 0;
					eth_src [BIT_WIDTH-17 : 0] <= data_in[INPUT_WIDTH-1 : INPUT_WIDTH-32];
					eth_type <= data_in[31:16];
					if (data_in[31:16] == 16'h08_00)begin
						next_state <= IP_HDR_S1;
						//offset <= offset +2;
					end
					ip_ver <= data_in [15 : 12];
					ip_hlen <= data_in [11 : 8];
					ip_tos <= data_in [7 : 0];
				end
			end
			ETH_VLAN: begin //5
				if (EN) begin
					//if (data_aligned[INPUT_WIDTH-17 : INPUT_WIDTH -32] == 16'h08_00) begin // 0800
					if (eth_type == 16'h08_00) begin // 0800
						next_state <= IP_HDR_S1; 
						//offset <= offset +4;
						
					end
					else begin
						next_state <= DROP_PACKET; 
						reset <= 1'd1;
					end
				end
			end
			IP_HDR_S1: begin		//6
				if (EN) begin
					ip_len <= data_in [63 : 48];
					ip_id <= data_in [47:32];
					ip_flag_frag_off <= data_in [31:16];
					ip_ttl <= data_in [15:8];
					ip_protocol <= data_in [7:0];
					if (ip_ver == 4'b0100) begin //0100
						next_state <= IP_HDR_S2;
					end
					else begin
						next_state <= DROP_PACKET; 
						reset<=1'd1;
					end
				end
			end
			IP_HDR_S2: begin //7
				if (EN) begin
					ip_checksum <= data_in [63:48];  
					ip_src_addr <= data_in [47:16];
					ip_dst_addr[31:16] <= data_in[15:0];
					next_state <= IP_HDR_OPT;
				end
			end
			IP_HDR_OPT: begin //8
				if (EN) begin
					ip_dst_addr[15:0] <= data_in [63:48];
					tcp_src_port_opt <= data_in[47:32];
					tcp_dst_port <= data_in[31:16];
					tcp_len <= data_in[15:0];
					if (ip_hlen == 4'b0101) begin //0101
						//offset <= offset + 4 ;
						next_state <= TCP_HDR_S1;
					end
					else if (ip_hlen == 4'b0110) begin
						ip_options <= data_aligned [31:0];
						next_state <= TCP_HDR_S1;
					end
					else begin
						next_state <= DROP_PACKET;
						reset <= 1'b1;
					end
				end
			end
			TCP_HDR_S1: begin //9
				if (EN) begin
					tcp_seq_num<= data_in[63:48];
					if (tcp_len == 16'h0008 )begin
						payload_len <= 16'h0000;
						next_state <= DONE;
					end
					else begin
						payload_len <= tcp_len - 16'h0008;
						next_state <= TCP_ACK_S1;
						offset <= 4'd6;
						//payload_data <= data_in[47:0];
						//done <= 1; 
					end
				end
			end
			TCP_ACK_S1: begin //10
			if (flag && 2'b10) begin
				tcp_ack<= data_in[63:32];
				next_state<=RESERVED;
			end
			else next_state<=DROP_PACKET;
			end
			RESERVED: begin //11
				if(data_in[59:56]==0)begin
				tcp_offset<=data_in[63:60];
				tcp_reserved<=data_in[59:56];
				tcp_flag<=data_in[55:52];
				tcp_windowsize<=data_in[51:36];
				next_state<=CHECKSUM;
				end
				else next_state<=DROP_PACKET;
				end
				CHECKSUM: begin //12
				tcp_checksum_opt<=data_in[63:48];
				tcp_pointer<=data_in[47:32];
				end
			PAYLOAD: begin //13
				if (end_packet && EN) begin
					packet_ended <= 1'b1;
				end
				if ((!packet_ended && EN) || packet_ended) begin
					if (payload_len > 16'd8) begin
						payload_data <= data_aligned;
						payload_len <= payload_len- 16'b0000_0000_0000_1000; 
						next_state <= PAYLOAD;
						done <= 1'b1;
					end
					else begin
						case (payload_len)
							16'h0001: begin
								payload_data <= {data_aligned [63:56], 56'h00000000000000};
								payload_len <= payload_len-1;
								done <= 1'b1;	
								//delay <= delay +1;
							end
							16'h0002: begin
								payload_data <= {data_aligned [63:48], 48'h000000000000};
								payload_len <= payload_len-2;
								done <= 1'b1;	
								//delay <= delay +1;
							end
							16'h0003: begin
								payload_data <= {data_aligned [63:40], 40'h0000000000};
								payload_len <= payload_len-3;
								done <= 1'b1;
								//delay <= delay +1;
							end
							16'h0004: begin
								payload_data <= {data_aligned [63:32], 32'h00000000};
								payload_len <= payload_len-4;
								done <= 1'b1;
								//delay <= delay +1;
							end
							16'h0005: begin
								payload_data <= {data_aligned [63:24], 24'h000000};
								payload_len <= payload_len-5;
								done <= 1'b1;
								//delay <= delay +1;
							end
							16'h0006: begin
								payload_data <= {data_aligned [63:16], 16'h0000};
								payload_len <= payload_len-6;
								done <= 1'b1;
								//delay <= delay +1;
							end
							16'h0007: begin
								payload_data <= {data_aligned [63:8], 8'h00};
								payload_len <= payload_len-7;
								done <= 1'b1;
								//delay <= delay +1;
							end
							16'h0008: begin
								payload_data <= data_aligned [63:0];
								payload_len <= payload_len-8;
								done <= 1'b1;
								//delay <= delay +1;
							end
							default: payload_data <= 64'h00000000_00000000;
						endcase
						//next_state<= START; 
						done_final <= 1'b1;
						next_state <= START;
						offset <= 4'b0000;
					//	done <=1'b0;
						//delay <=delay +1 ;
					end
				end else begin
					done <= 1'b0;
				end
			end
			DROP_PACKET: begin
				next_state <= START; 
			end
			default: next_state <= START;
		endcase	
	end		
	end				

always @ (posedge clk) begin
	if (!reset_n) begin
		writeReq <= 1'b0;
		write_delay <= 1'b0;
	end else begin
		write_delay <= done;
		if (state == PAYLOAD) begin
			writeReq <= 1'b1;
		end else begin
			writeReq <= write_delay;
		end
	end
end

	
endmodule 
	
