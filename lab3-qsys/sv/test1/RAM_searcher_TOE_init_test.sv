module RAM_searcher (input logic 		rs_clk,
		     input logic 		rs_rst,
		     input logic [1:0] 		rs_rq,
		     input logic [7:0] 		rs_id_in,
		     input logic [31:0] 	rs_ip_src,
		     input logic [31:0] 	rs_ip_dst,
		     input logic [23:0]         rs_mac_src,
		     input logic [23:0]         rs_mac_dst,
         	     input logic [15:0]         rs_port_src,
		     input logic [15:0]         rs_port_dst,
		     output logic [7:0]		rs_return);
		
//To be implemented by Qi

	logic [3:0] counter;

	always_ff @ (posedge rs_clk) 
		begin 
		if (rs_rst)
			 begin 
			 counter <= 4'd0;
			 rs_return <= 8'd0;
			 end 
		else if (rs_rq == 2'b00) 
			 begin 
			 counter <= 4'd0; 
			 end
		else
			begin 
			if (counter != 4'hf)  counter <= counter + 4'd1;
			if (counter ==	4'hff) rs_return <= {counter, counter};
			end
		end 
endmodule 
