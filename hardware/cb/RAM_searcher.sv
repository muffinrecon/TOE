/* Lay out of the data in memory
 * First Slot as Valid and State (32 bits)
 * Seq number (32 bits) 
 * Ack number (32 bits) 
 * ip_src (32bits)
 * ip_dst (32 bits)   
 * mac_src1 (32 bits)
 * mac_src2 (16 bits + 16 bits of padding)
 * mac_dst1 (32 bits)
 * mac_dst2 (16 bits + 16 bits of padding)
 * src_port + dst_port (16 bits each) 
 * 1 record is 10 4-bytes word = 40 bytes 
 * 256 bytes RAM 
 */

module RAM_searcher( 	input logic         clk,
	      		input logic         rst,
	      		input logic  [1:0]  req, 
	      		output logic [7:0]  reply,
	      		input logic  [7:0]  id_in,	
	      		input logic  [31:0] ip_src,
	      		input logic  [31:0] ip_dst,
	     		input logic  [47:0] mac_src, 
	      		input logic  [47:0] mac_dst, 
	      		input logic  [15:0] port_src,
	      		input logic  [15:0] port_dst,
			output logic [7:0]  addr,
			output logic [31:0] data,
			input logic  [31:0]  q,
			output logic 	    wren	
			);


parameter LAST_RECORD = 8'd240;
parameter TCP_CLOSED = 31'd1;
parameter REQ_CONN = 2'b01;
parameter REQ_DEL = 2'b10;
parameter ERR_FOUND = 8'b1000_0000;
parameter ERR_FULL  = 8'b1100_0000;

logic [8:0] empty;
logic [7:0] base_addr;
logic s_done;
logic ins_done;
logic found;
logic last_record;

/* States of the high-level automata */ 
enum logic [2:0] {hl_IDLE, hl_SEARCHING, hl_DELETING, hl_INSERTING, hl_RETURN_SUCCESS, hl_ERROR_FOUND, hl_ERROR_FULL} hl_state; 

/* States of the second level automata for searching a matching connection in the RAM */ 
enum logic [1:0] {s_IDLE, s_FETCH_VALID, s_CHECK, s_FOUND} s_state; 

/* States of the second level automata for searching a matching connection in the RAM */ 
enum logic [3:0] {chk_IDLE, chk_DONE, chk_VALID, chk_IP_SRC, chk_IP_DST, chk_MAC_SRC1, chk_MAC_SRC2, chk_MAC_DST1, chk_MAC_DST2, chk_PORTS, chk_EQUAL, chk_WAIT} chk_state;

/* States for INSERTION of new record */ 
enum logic [3:0] {ins_IDLE, ins_VALID_STATE, ins_SEQ, ins_ACK, ins_IP_SRC, ins_IP_DST, ins_MAC_SRC1, ins_MAC_SRC2, ins_MAC_DST1, ins_MAC_DST2, ins_PORTS} ins_state;

assign last_record =  (base_addr == LAST_RECORD); 
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
						REQ_CONN   :  hl_state <= hl_SEARCHING;
						REQ_DEL  :  hl_state <= hl_DELETING;
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
						reply <= ERR_FOUND; 
						end
					else 		hl_state <= hl_SEARCHING;
				end 
			hl_INSERTING : 
				begin
					if (ins_done)
						begin     
						hl_state <= hl_RETURN_SUCCESS;
						reply <= {1'b0, empty[7:1]}; // Return the id of the connection1
						end 
					else if (empty[8] == 1) 
						begin
						hl_state <= hl_ERROR_FULL;
						reply <= ERR_FULL;  
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
					if (chk_done) base_addr <= base_addr + 8'd10;
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
			chk_MAC_SRC1 	 : addr = base_addr + 8'd7;
			chk_MAC_SRC2	 : addr = base_addr + 8'd8;
			chk_MAC_DST1 	 : addr = base_addr + 8'd9;
			chk_MAC_DST2	 : addr = base_addr;
			default 	 : addr = base_addr;
		endcase		
	  else if (hl_state == hl_INSERTING) 
		case (ins_state)	
			ins_IDLE	 : addr = empty[7:0];
			ins_VALID_STATE  : addr = empty[7:0];
			ins_SEQ		 : addr = empty[7:0] + 8'd1;
			ins_ACK		 : addr = empty[7:0] + 8'd2;
			ins_IP_SRC	 : addr = empty[7:0] + 8'd3;
			ins_IP_DST	 : addr = empty[7:0] + 8'd4;
			ins_MAC_SRC1	 : addr = empty[7:0] + 8'd5;
			ins_MAC_SRC2	 : addr = empty[7:0] + 8'd6;
			ins_MAC_DST1	 : addr = empty[7:0] + 8'd7;
			ins_MAC_DST2	 : addr = empty[7:0] + 8'd8;
			ins_PORTS	 : addr = empty[7:0] + 8'd9;	
			default		 : addr = empty[7:0];
		endcase 
	else if (s_state == hl_DELETING) addr = {id_in[6:0], 1'b0};
	else addr = empty[7:0];

	end

always_comb 
	begin
	if (hl_state == hl_INSERTING)
		case(ins_state) 
			ins_IDLE	 : data = 32'd0;
			ins_VALID_STATE  : data = {1'b1, TCP_CLOSED}; 
			ins_SEQ		 : data = 32'd0;
			ins_ACK		 : data = 32'd0;
			ins_IP_SRC	 : data = ip_src;
			ins_IP_DST	 : data = ip_dst;
			ins_MAC_SRC1	 : data = mac_src[47:16];
			ins_MAC_SRC2	 : data = {mac_src[15:0], 16'd0};
			ins_MAC_DST1	 : data = mac_dst[47:16];
			ins_MAC_DST2	 : data = {mac_dst[15:0], 16'd0};
			ins_PORTS	 : data = {port_src, port_dst};
			default 	 : data = 32'd0;
		endcase
	else if(hl_state == hl_DELETING) data = 32'd0; 
	else data = 32'd0;  
	end 


always_comb 
	begin 
	if (hl_state == hl_INSERTING)
		case (ins_state) 
			ins_IDLE	 : wren = 1'b0;
			ins_VALID_STATE  : wren = 1'b1;
			ins_SEQ		 : wren = 1'b1;
			ins_ACK		 : wren = 1'b1;
			ins_IP_SRC	 : wren = 1'b1;
			ins_IP_DST	 : wren = 1'b1;
			ins_MAC_SRC1	 : wren = 1'b1;
			ins_MAC_SRC2	 : wren = 1'b1;
			ins_MAC_DST1	 : wren = 1'b1;
			ins_MAC_DST2	 : wren = 1'b1;
			ins_PORTS	 : wren = 1'b1; 
			default 	 : wren = 1'b0;
		endcase
	else if (hl_state == hl_DELETING) wren = 1'b1;
	else wren = 1'b0;
	end 


always_comb
	begin
	if (chk_state == chk_DONE) chk_done = 1'b1;
	else chk_done = 1'b0; 
	end 

	
always_ff @ (posedge clk)
	begin
	if(rst) 
		begin
		chk_state <= chk_IDLE;
		end 
	if(s_state == s_CHECK)
		case (chk_state) 
			chk_DONE	: chk_state <= chk_IDLE;
			
			chk_IDLE  	: chk_state <= chk_WAIT;
			chk_WAIT 	:
				begin 
				chk_state <= chk_VALID;
				end
			chk_VALID	: 
				begin
				if(q[31] == 1'b1) chk_state <= chk_IP_SRC;
				else	
					begin
					empty <= {1'b0, base_addr};
					chk_state <= chk_DONE;
					end
				end		
			chk_IP_SRC	: 
				begin
				if(q == ip_src) chk_state <= chk_IP_DST;
				else	chk_state <= chk_DONE;
				end 
			chk_IP_DST	: 
				begin
				if(q == ip_dst) chk_state <= chk_MAC_SRC1;
				else 	chk_state <= chk_DONE;
				end
			chk_MAC_SRC1	: 
				begin
				if(q == mac_src[47:16]) chk_state <= chk_MAC_SRC2;
				else 	chk_state <= chk_DONE;
				end 
			chk_MAC_SRC2	: 
				begin
				if(q[31:16] == mac_src[15:0]) chk_state <= chk_MAC_DST1;
				else 	chk_state <= chk_DONE;
				end 
			chk_MAC_DST1	: 
				begin
				if(q == mac_dst[47:16]) chk_state <= chk_MAC_DST2; 
				else 	chk_state <= chk_DONE;
				end 
			chk_MAC_DST2	: 
				begin
				if(q[31:16] == mac_dst[15:0]) chk_state <= chk_PORTS; 
				else	chk_state <= chk_DONE;
				end 
			chk_PORTS	:
				begin
				if(q == {port_src, port_dst}) chk_state <= chk_EQUAL;
				else 	chk_state <= chk_DONE;
				end 
			chk_EQUAL : chk_state <= chk_IDLE;
		endcase
	else if (hl_state == hl_IDLE) empty <= 8'd0; 
 		
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
			ins_IP_DST 	: ins_state <= ins_MAC_SRC1;
			ins_MAC_SRC1 	: ins_state <= ins_MAC_SRC2;
			ins_MAC_SRC2 	: ins_state <= ins_MAC_DST1;
			ins_MAC_DST1 	: ins_state <= ins_MAC_DST2;
			ins_MAC_DST2 	: ins_state <= ins_PORTS;
			ins_PORTS :
				begin
				ins_state <= ins_IDLE;
				ins_done  <= 1'b1; 
				end
		endcase 		
	end

endmodule

