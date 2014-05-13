/* TO DO MODULE
 * - add proper initialization for the SYN
 * - add deleting function
 * /



/* Lay out of the data in memory
 * First Slot as Valid and State (32 bits)
 * Seq number (32 bits) 
 * Ack number (32 bits) 
 * ip_src (32bits)
 * ip_dst (32 bits)   
 * mac_src (24 bits + 8 bits of padding)
 * mac_dst (24 bits + 8 bits of padding)
 * src_port + dst_port (16 bits each) 
 * 1 record is 8 4-bytes word  8*4 = 32 bytes 
 * 256 bytes RAM 8 connections
 */

module RAM_searcher( 	input logic         clk,
	      		input logic         rst,
	      		input logic  [1:0]  req, 
	      		output logic [7:0]  reply,
	      		input logic  [7:0]  id_in,	
	      		input logic  [31:0] src_ip,
	      		input logic  [31:0] dst_ip,
	     		input logic  [23:0] src_mac, 
	      		input logic  [23:0] dst_mac, 
	      		input logic  [15:0] src_port,
	      		input logic  [15:0] dst_port);

logic [8:0] addr;
logic [31:0] ram_in;
logic [31:0] ram_out;
logic wren;
logic [8:0] empty;

RAM connection_RAM (.address (addr[7:0]), .clock (clk), .data(ram_in), .wren(wren), .q(ram_out));

/* States of the high-level automata */ 
enum logic [2:0] {hl_IDLE, hl_SEARCHING, hl_DELETING, hl_INSERTING, hl_RETURN_SUCCESS, hl_ERROR_FOUND, hl_ERROR_FULL} hl_state; 

/* States of the second level automata for searching a matching connection in the RAM */ 
enum logic [1:0] {s_IDLE, s_FETCH_VALID, s_CHECK, s_FOUND} s_state; 
logic s_done;

/* States of the second level automata for searching a matching connection in the RAM */ 
enum logic [3:0] {chk_IDLE, chk_VALID, chk_IP_SRC, chk_IP_DST, chk_MAC_SRC, chk_MAC_DST, chk_PORTS, chk_EQUAL, chk_WAIT} chk_state;

/* States for INSERTION of new record */ 
enum logic [3:0] {ins_IDLE, ins_VALID_STATE, ins_SEQ, ins_ACK, ins_IP_SRC, ins_IP_DST, ins_MAC_SRC, ins_MAC_DST, ins_PORTS} ins_state;
logic ins_done;

logic [7:0] 	base_addr;


logic last_record;
assign last_record =  (base_addr == 8'd224); 

logic found;
assign found = (chk_state == chk_EQUAL);



/* High Level State Machine */ 
always_ff @ (posedge clk)
	begin 
	if(rst) 
		begin
		hl_state <= hl_IDLE;
		reply <= 8'b0;
		end 
	else 
		case (hl_state) 
			hl_IDLE : 
				begin 
					case (req) 
						2'b01   :  hl_state <= hl_SEARCHING;
						2'b10   :  hl_state <= hl_DELETING;
						default :  hl_state <= hl_IDLE;
					endcase
					reply <= 8'b0; 
				end 
			hl_DELETING :
				begin 
					hl_state <= hl_RETURN_SUCCESS;
				end 
			hl_SEARCHING :
				begin
					if (s_done) 	hl_state <= hl_INSERTING;
					else if (found) 
						begin
						hl_state <= hl_ERROR_FOUND;
						reply <= {1'd1, 7'd0}; 
						end
					else 		hl_state <= hl_SEARCHING;
				end 
			hl_INSERTING : 
				begin
					if (ins_done)
						begin     
						hl_state <= hl_RETURN_SUCCESS;
						reply <= {3'd0, empty[7:3]}; 	
						end 
					else if (empty[8] == 1) 
						begin
						hl_state <= hl_ERROR_FULL;
						reply <= {1'b0, 1'b1, 6'd0};  
						end 
					else hl_state <= hl_INSERTING;				 
				end 
			hl_RETURN_SUCCESS : 
				begin 
					if (req == 2'b00) hl_state <= hl_IDLE;
					else 		 hl_state <= hl_RETURN_SUCCESS;
				end 
			hl_ERROR_FOUND : 
				begin
					if (req == 2'b00) hl_state <= hl_IDLE;
					else hl_state <= hl_ERROR_FOUND;	
				end
			hl_ERROR_FULL : 
				begin 
					if (req == 2'b00) hl_state <= hl_IDLE;
					else 		 hl_state <= hl_ERROR_FULL;	
				end 
			default : hl_state <= hl_state;
		endcase 
	end 

logic chk_done; 
/* Search automata */ 
always_ff @ (posedge clk) 
	begin
	if (rst)
		begin 
		s_state <= s_IDLE;
		base_addr <= 8'd0;
		chk_done <= 1'b0;
		end
	else if (hl_state == hl_SEARCHING) 
		case (s_state)  
			s_IDLE :
				begin 		
				if (s_done)
					begin
					s_state <= s_IDLE; // No overlay of fetching and checking during first
					base_addr <= 8'd0;
					s_done <= 1'b0;
					end
				else    s_state <= s_CHECK;
				end		

			s_CHECK :
				begin
				if(found)  
					begin
					s_state <= s_IDLE;
					base_addr <= 8'd0;
					end
				else if (chk_done && last_record) 
					begin
					s_done <= 1; 
					s_state <= s_IDLE;
					end
				else
					begin
					s_state <= s_CHECK;
					if (chk_done) base_addr <= base_addr + 8'd8;
					end
				end
		endcase
	end


// There could be some endianess issue when placing data in the RAM
always_comb 
	begin
	   if (hl_state == hl_SEARCHING) 
		case (chk_state) 
			chk_IDLE   	 : addr = base_addr;
			chk_WAIT	 : addr = base_addr + 8'd3;
			chk_VALID	 : addr = base_addr + 8'd4;
			chk_IP_SRC	 : addr = base_addr + 8'd5;
			chk_IP_DST	 : addr = base_addr + 8'd6;
			chk_MAC_SRC 	 : addr = base_addr + 8'd7;
			chk_MAC_DST 	 : addr = base_addr ;
			default 	 : addr = base_addr;
		endcase		
	  else if (hl_state == hl_INSERTING) 
		case (ins_state)	
			ins_IDLE	 : 
				begin
				addr = empty[7:0];
				wren = 1'b0; 
				end 
			ins_VALID_STATE  :
				begin	 
				addr = empty[7:0];
				wren = 1'b1;
				// Need an encoding for the TCP states 
				ram_in = { 1,31'hfaaaaaaa}; 
				end
			ins_SEQ		 : 
				begin
				addr = empty[7:0] + 8'd1 ;
				wren = 1'b1;
				ram_in = 32'd0;
				end
			ins_ACK		 : 
				begin
				addr = empty[7:0] + 8'd2 ;
				wren = 1'b1;
				ram_in = 32'd0;
				end
			ins_IP_SRC	 :
				begin
				addr = empty[7:0] + 8'd3;
				wren = 1'b1;
				ram_in = src_ip;
				end
			ins_IP_DST	 : 
				begin
				addr = empty[7:0] + 8'd4;
				wren = 1'b1;		
				ram_in = dst_ip;
				end
			ins_MAC_SRC	 : 
				begin
				addr = empty[7:0] + 8'd5;
				wren = 1'b1;
				ram_in = {src_mac, 8'd0};
				end
			ins_MAC_DST	 : 
				begin
				addr = empty[7:0] + 8'd6;
				wren = 1'b1;
				ram_in = {dst_mac, 8'd0};
				end
			ins_PORTS	 :
				begin 
				addr = empty[7:0] + 8'd7;		
				wren = 1'b1;
				ram_in = {src_port, dst_port};
				end	 
			default		 :
				begin 
				addr = empty[7:0];
				wren = 1'b0;
				end
		endcase 
	else if (hl_DELETING) 
		begin
		addr = {id_in[4:0], 3'd0};
		wren = 1'b1;	
		ram_in = 32'd0;  
		end
	else wren = 1'b0; 
	end

	
always_ff @ (posedge clk)
	begin
	if(rst) 
		begin
		chk_state <= chk_IDLE;
		chk_done <= 0;
		end 
	if(s_state == s_CHECK)
		case (chk_state) 
			chk_IDLE  	:
				begin
				if (chk_done)
					begin	 
					chk_state <= chk_IDLE;
					chk_done <= 1'b0;
					end
				else chk_state <= chk_WAIT;
				end 
			chk_WAIT 	:
				begin 
				chk_state <= chk_VALID;
				empty <= 9'b1_0000_0000;
				end
			chk_VALID	: 
				begin
				if(ram_out[31] == 1'b1) 
					chk_state <= chk_IP_SRC;
				else	
					begin
					empty <= {0, base_addr};
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end		
			chk_IP_SRC	: 
				begin
				if(ram_out == src_ip) chk_state <= chk_IP_DST;
				else 
					begin
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end 
			chk_IP_DST	: 
				begin
				if(ram_out == dst_ip) chk_state <= chk_MAC_SRC;
				else 
					begin 
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end
			chk_MAC_SRC	: 
				begin
				if(ram_out[31:8] == src_mac) chk_state <= chk_MAC_DST;
				else 
					begin
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end 
			chk_MAC_DST	: 
				begin
				if(ram_out[31:8] == dst_mac) chk_state <= chk_PORTS; 
				else 
					begin
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end 
			chk_PORTS	:
				begin
				if(ram_out == {src_port, dst_port}) chk_state <= chk_EQUAL;
				else 
					begin
					chk_state <= chk_IDLE;
					chk_done <= 1'b1;
					end
				end 
			chk_EQUAL : chk_state <= chk_IDLE;
		endcase 		
	end
		
always_ff @ (posedge clk)
	begin
	if(rst) 
		begin
		ins_state <= ins_IDLE;
		ins_done <= 1'b0;
		end 
	if(hl_state == hl_INSERTING)
		case (ins_state) 
			ins_IDLE  	:
				begin
				if (ins_done)
					begin
					ins_done <= 1'b0;
					ins_state <= ins_IDLE;
					end
				else ins_state <= ins_VALID_STATE; 
				end 
			ins_VALID_STATE	: ins_state <= ins_SEQ;			
			ins_SEQ		: ins_state <= ins_ACK;
			ins_ACK		: ins_state <= ins_IP_SRC;  
			ins_IP_SRC	: ins_state <= ins_IP_DST;
			ins_IP_DST 	: ins_state <= ins_MAC_SRC;
			ins_MAC_SRC 	: ins_state <= ins_MAC_DST;
			ins_MAC_DST 	: ins_state <= ins_PORTS;
			ins_PORTS :
				begin
				ins_state <= ins_IDLE;
				ins_done  <= 1'b1; 
				end
		endcase 		
	end

endmodule

