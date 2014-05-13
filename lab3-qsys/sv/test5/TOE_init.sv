module TOE_init( input logic		clk,
		 input logic 		rst,
		
		 // Avalon MM slave interface
	         input  logic [31:0]  	writedata,
	         input  logic 	        write,
	         output logic [31:0]  	readdata,   
	         input  logic 	  	read,
	         input  logic	  	chipselect,
	         input  logic [3:0]   	address
		);

	enum logic [1:0] {WAIT_RQ, PROCESSING, RETURN} state; 
	
	logic [1:0] mm_rq;
	logic [7:0] mm_id;
	logic [7:0] mm_return;
	logic [31:0] mm_ip_src;
	logic [31:0] mm_ip_dst;
	logic [23:0] mm_mac_src;
	logic [23:0] mm_mac_dst;
	logic [15:0] mm_port_src;	
	logic [15:0] mm_port_dst;	

	logic [1:0] latch_rq;

	RAM_searcher rs0 (.clk(clk),
			  .rst(rst),
			  .src_ip(mm_ip_src),
			  .dst_ip(mm_ip_dst),
			  .src_mac(mm_mac_src),
			  .dst_mac(mm_mac_dst),
			  .src_port(mm_port_src),
			  .dst_port(mm_port_dst),
			  .req(latch_rq),
			  .reply(mm_return),
			  .id_in(mm_id)
			  );
	
	always_ff @ (posedge clk) 
		begin
		if (rst)
			begin 
			state       <= WAIT_RQ; 
			mm_rq       <= 2'd0;
			mm_id       <= 8'd0;
			mm_ip_src   <= 32'd0;
			mm_ip_dst   <= 32'd0;
			mm_mac_src  <= 24'd0;
			mm_mac_dst  <= 24'd0;
			mm_port_src <= 16'd0;
			mm_port_dst <= 16'd0;
			readdata    <= 32'd0;
			end 
		else if ((state == WAIT_RQ) && (mm_rq != 2'b00)) state <= PROCESSING;
		else if ((state == PROCESSING) && (mm_return != 8'd0)) state <= RETURN;
		else if ((state == RETURN) && (mm_rq == 2'b00)) state <= WAIT_RQ;    		
		else if (write && chipselect) 
			case (address)
		  	4'h0 : mm_rq    <= writedata[1:0];
		  	4'h1 : if (state == WAIT_RQ) mm_id    <= writedata[7:0]; 
			// 2 is for return, driven by RAM_searcher and shouldn't be written
		  	4'h3 : if (state == WAIT_RQ) mm_ip_src   <= writedata;
		  	4'h4 : if (state == WAIT_RQ) mm_ip_dst   <= writedata;
		   	4'h5 : if (state == WAIT_RQ) mm_mac_src  <= writedata[23:0];
		  	4'h6 : if (state == WAIT_RQ) mm_mac_dst  <= writedata[23:0];
		  	4'h7 : if (state == WAIT_RQ) mm_port_src <= writedata[15:0];
		  	4'h8 : if (state == WAIT_RQ) mm_port_dst <= writedata[15:0];
			endcase
		else if(read && chipselect)
			begin
			case (address)
		  	4'h0 : readdata[1:0]  <= mm_rq;
		  	4'h1 : readdata[7:0]  <= mm_id;
		  	4'h2 : begin
			       readdata[31:8] <= 24'd0; 
			       readdata[7:0]  <= mm_return;
			       end    
		  	4'h3 : readdata       <= mm_ip_src;
		  	4'h4 : readdata       <= mm_ip_dst;
		  	4'h5 : readdata[23:0] <= mm_mac_src;
		  	4'h6 : readdata[23:0] <= mm_mac_dst;
		 	4'h7 : readdata[15:0] <= mm_port_src;
		  	4'h8 : readdata[15:0] <= mm_port_dst;  
			endcase
			end
		end 
		 
	always_comb 
		begin 
		if (state == WAIT_RQ)
			begin 
			latch_rq <= 2'b00;
			end 
		if (state == PROCESSING) 
			begin
			latch_rq <= mm_rq;
			end
		if (state == RETURN)
			begin 
			end 
		end 
		

//Separate in separate processes
		
endmodule
