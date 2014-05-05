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

	// req_code take 2'b01 for new connection, 2'b10 to kill connection 
	logic [1:0] req_code;
	logic done;
	logic [7:0] error;
	logic [31:0] ip_src;
	logic [31:0] ip_dst;
	logic [23:0] mac_src;
	logic [23:0] mac_dst;
	logic [15:0] port_src;	
	logic [15:0] port_dst;	
	logic [7:0]  id_in;
	logic [7:0]  id_out; 

	logic rs_done;
	logic rq;

	assign rq = (req_code != 2'b00) & (~done); 

	RAM_searcher rs0 (.rs_clk(clk),
			  .rs_rst(rst),
			  .rs_ip_src(ip_src),
			  .rs_ip_dst(ip_dst),
			  .rs_mac_src(mac_src),
			  .rs_mac_dst(mac_dst),
			  .rs_port_src(port_src),
			  .rs_port_dst(port_dst),
			  .rs_rq(req_code),
			  .rs_error(error),
			  .rs_done(rs_done),
			  .rs_id_in(id_out),
			  .rs_id_out(id_in)
			  );
			   

	always_ff @ (posedge clk)
		begin
		if (rst)
			begin
				req_code   <= 2'b0;
				done       <= 1'b0;
			end  
		else if (write && chipselect) 
			case (address)
		  	   4'h0 : req_code      <= writedata[1:0];
		 	   4'h1 : done          <= writedata[0]; // Should be use to write 0 to done once read
			   // 2 is for error, driven by RAM_searcher and shouldn't be written
		  	   4'h3 : ip_src   <= writedata;
		  	   4'h4 : ip_dst   <= writedata;
		   	   4'h5 : mac_src  <= writedata[23:0];
		  	   4'h6 : mac_dst  <= writedata[23:0];
		  	   4'h7 : port_src <= writedata[15:0];
		  	   4'h8 : port_dst <= writedata[15:0];
			   // 9 is for id_in, driven by RAM_searcher and shouldn't be written
			   4'hA : id_out   <= writedata[7:0];
			endcase
		else
	    		begin
			   if(rq)
				begin 
				done <= 1'b1;
				req_code <= 2'b00;
				end 
			   if(read && chipselect)
					begin
					readdata <= 32'd0;
					case (address)
		  	   	    	   4'h0 : readdata[1:0]  <= req_code;
		  	   	    	   4'h1 : readdata[0]    <= done;
		  	   	    	   4'h2 : readdata[3:0]  <= error;    
		  	   	    	   4'h3 : readdata       <= ip_src;
		  	   	    	   4'h4 : readdata       <= ip_dst;
		  	   	    	   4'h5 : readdata[23:0] <= mac_src;
		  	   	    	   4'h6 : readdata[23:0] <= mac_dst;
		 	   	    	   4'h7 : readdata[15:0] <= port_src;
		  	   	    	   4'h8 : readdata[15:0] <= port_dst;
		  	   	    	   4'h9 : readdata[7:0]  <= id_in;
		  	   	    	   4'hA : readdata[7:0]  <= id_out;
					endcase
					end
			end 
			
		end 
endmodule

		
