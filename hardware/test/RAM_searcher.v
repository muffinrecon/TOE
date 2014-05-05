module RAM_searcher (input wire		rs_clk,
		     input wire 	rs_rst,
		     input wire [1:0] 	rs_rq,
		     input wire [7:0]   rs_id_in,
		     input wire [31:0] 	rs_ip_src,
		     input wire [31:0] 	rs_ip_dst,
		     input wire [23:0]  rs_mac_src,
		     input wire [23:0]  rs_mac_dst,
                     input wire [15:0]  rs_port_src,
		     input wire [15:0]  rs_port_dst,
		     output reg [7:0]	rs_error,
		     output reg 	rs_done,  
		     output reg [7:0]	rs_id_out);
		
// The connection RAM can be taken out of this module later on. 
// Dummy implementation for testing

	reg [3:0] counter;
	reg prev_rq;


 	always @ (posedge rs_clk)
		begin
		if (rs_rst)
			begin 
			rs_error <= 8'b0;
			rs_id_out <= 8'b0;
			rs_done <=  1'b0;
			counter <= 4'd0;
			prev_rq <= 1'b0;
			end
		else
			begin 
			prev_rq <= rs_rq[0];
			counter <= counter + 4'b1;
			if (rs_rq[0] && ~prev_rq) counter <= 4'd0;
			if (rs_rq[0] && (counter == 4'hf)) 
				begin
				rs_done <= 1'b1;
				rs_id_out <= 8'h99;
				end	
			if (~rs_rq[0]) rs_done <= 1'b0; 
			end
		end 


endmodule 
