/* Lay out of the data in memory
 * First slots of memory are for valid bits
 * Seq number (32 bits) 
 * Ack number (32 bits) 
 * ip_src (32bits)
 * ip_dst (32 bits)   
 * mac_src (24 bits + 8 bits of padding)
 * mac_dst (24 bits + 8 bits of padding)
 * src_port + dst_port (16 bits each) 
 * 1 record is 7 4-bytes word rounded up to 8*4 = 32 bytes 
 * 
 */


RAM_searcher( input logic         clk,
	      input logic         rst,
	      input logic  [1:0]  req 
	      output logic [7:0]  return,
	      input logic  [7:0]  id_in,	
	      input logic  [31:0] src_ip,
	      input logic  [31:0] dst_ip,
	      input logic  [23:0] src_mac, 
	      input logic  [23:0] dst_mac, 
	      input logic  [15:0] src_port,
	      input logic  [15:0] dst_port);



RAM connection_RAM (.address (addr), .clock (clk), .data(data_in), .wren(wren), .q(data_out));

enum logic [2:0] {IDLE, SEARCHING, DELETING, INSERTING, RETURN_SUCCESS, ERROR_FOUND, ERROR_FULL} state; 

logic valid; 
logic [31:0] 	ftch_src_ip;
logic [31:0] 	ftch_dst_ip;
logic [23:0] 	ftch_src_mac;
logic [23:0] 	ftch_dst_mac;
logic [15:0] 	ftch_src_port;
logic [15:0] 	ftch_dst_port;

// add checking of the valid bit. Keep track of the first available spot.

logic 		equal;
assign 	equal = (ftch_src_ip == src_ip) && (ftch_dst_ip == dst_ip)
	 && (ftch_src_mac == dst_mac) && (ftch_dst_mac == src_mac)
	 && (ftch_src_port == dst_port) && (ftch_dst_port == src_port); 

logic 		counter; // add size and initialization below	
logic 		found;
logic 		del_done;

logic 		wren;		
logic [11:0] 	addr;
logic 		data_out;
logic 		data_in; 

always_ff @ (posedge clk)
	begin 
	if(rst) 
		begin
		state <= IDLE; // Assume the RAM is initialized with all-0's
		end 	
	else if ((state == IDLE) && (rq == 2'b01)) state <= SEARCHING; 
	else if ((state == IDLE) && (rq == 2'b10)) state <= DELETING;
	else if ((state == DELETING) && del_done)  state <= RETURN_SUCCESS;
	else if ((state == SEARCHING) && end) state <= INSERTING;
	else if ((state == SEARCHING) && found) state <= ERROR_FOUND;
	else if ((state == INSERTING) && end) state <= ERROR_FULL; 
	else if ((state == RETURN_SUCCESS) && (rq == 2'b00)) state <= IDLE; 
	else if ((state == ERROR_FOUND) && (rq == 2'b00)) state <= IDLE; 
	else if ((state == ERROR_FULL) && (rq == 2'b00)) state <= IDLE; 
	end 

always_ff @ (posedge clk) 
	if (state == SEARCHING) 
		begin
		// Fetch the data  
		end 
		

always@(posedge clk) begin	
	if(req)
	 begin
		for (int i=0;i<=counter;i++) begin
			addr <= i;
			if (data_in_delayed2 == data_out) begin
				wren <= 1'b0; //disable wren
				ID <= addr; // assign ID as addr
				not_found <= 1'b0; //set not_found to false
				con_existed <= 1'b1; //there is an exsiting connection
				end
		end
		addr <= ID;//not sure of this
		if (not_found)	begin
			wren <= 1'b1; //enable wren
			counter <= counter + 1'b1; //counter ++;
			ID <= counter; //return ID as counter
			con_existed <= 1'b0; //no exsiting connection
			not_found <= 1'b0; //reset not_found to false
		end
	end
	
	//write to RAM, 
	if(wren)begin
		addr <= ID;//RAM address as ID
		
	end
end

endmodule

