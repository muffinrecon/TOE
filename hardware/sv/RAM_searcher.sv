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
		     output logic [7:0]		rs_error,
		     output logic 		rs_done,  
		     output logic [7:0]		rs_id_out);
		
//To be implemented by Qi

endmodule 
