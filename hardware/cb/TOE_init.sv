module TOE_init( input logic		clk,
		 input logic 		rst,
		
		 input logic [1:0]	req_code,	
		 input logic [7:0] 	id_in,
		 output logic [7:0] 	reply,
		 input logic [31:0] 	ip_src,
		 input logic [31:0] 	ip_dst,
		 input logic [47:0] 	mac_src,
		 input logic [47:0] 	mac_dst,	
		 input logic [15:0] 	port_src,
		 input logic [15:0]	port_dst,
		 output logic [31:0]    data,
		 output logic 		wren,
		 output logic [7:0]	addr,
		 input logic [31:0]	q
		);

	enum logic [1:0] {WAIT_RQ, PROCESSING, RETURN} state; 
	

	logic [1:0] latch_rq;

	RAM_searcher rs0 (.clk(clk),
			  .rst(rst),
			  .req(req_code),
			  .reply(reply),
			  .id_in(id_in),
			  .ip_src(ip_src),
			  .ip_dst(ip_dst),
			  .mac_src(mac_src),
			  .mac_dst(mac_dst),
			  .port_src(port_src),
			  .port_dst(port_dst),
			  .addr(addr),
			  .data(data),
			  .q(q),
			  .wren(wren)
			  );
	
	always_ff @ (posedge clk) 
		begin
		if (rst)
			begin 
			state       <= WAIT_RQ; 
			end 
		else if ((state == WAIT_RQ) && (req_code != 2'b00)) state <= PROCESSING;
		else if ((state == PROCESSING) && (reply != 8'd0)) state <= RETURN;
		else if ((state == RETURN) && (req_code == 2'b00)) state <= WAIT_RQ;    		
		end 
		
endmodule
