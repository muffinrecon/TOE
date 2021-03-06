module testbench();

	logic 		clk;
	logic 		rst;
	logic [31:0]  	writedata;
	logic 	        write;
	wire [31:0]  	readdata;   
	logic 	  	read;
	logic	  	chipselect;
	logic [3:0]   	address;

	TOE_init t0(.*);
	
	initial
		begin
		writedata = 32'd0;
		write = 1'd0;
		read = 1'd0;
		chipselect = 1'd0;
		address = 4'd0;
		end
	
	initial clk = 1'b0;
	always #20 clk = ~clk;

	initial
		begin
		// Reset
		rst = 0;
		@ (posedge clk);
		rst = 1;
		@ (posedge clk);
		rst = 0;
		
		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;		
		address = 4'd3; //ip_src
		writedata = 32'h11111111;
		
		@ (posedge clk);
		chipselect = 1'b0;
		write = 1'b0;		

		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd4; //ip_dst
		writedata = 32'h22222222;
	
		@ (posedge clk);
		chipselect = 1'b0;
		write = 1'b0;

		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd5; //mac_src
		writedata = 32'h00333333;
	
		@ (posedge clk);
		chipselect = 1'b0;
		write =1'b0;
		
		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd6; //mac_src
		writedata = 32'h00444444;
		
		@ (posedge clk);
		chipselect = 1'b0;
		write = 1'b0;
		
		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd7; //port_src
		writedata = 32'h00005555;
		
		@ (posedge clk);
		chipselect = 1'b0;
		write = 1'b0;
		
		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd8; //port_src
		writedata = 32'h00006666;

		@ (posedge clk);
		chipselect = 1'b0;
		write = 1'b0;

		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		address = 4'd0; //req
		writedata = 32'h00000001;	

		@ (posedge clk);
		write = 1'b0;
		address = 4'd1;
		read = 1'b1;

		wait(readdata == 32'd1); 
		
		@ (posedge clk);
		chipselect = 1'b1;
		write = 1'b1;
		read = 1'b0;
		address = 4'd1; //port_src
		writedata = 32'd0;
		
		
		end

		

endmodule
