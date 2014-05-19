/*
 * Module containing all interfaces for the TOE 
 *
 * Clementine Barbet
 * cb3022
 */

module TOE ( input  logic         clk,
	     input  logic 	  rst,

	     // Avalon MM slave interface
	     input  logic [31:0]  writedata,
	     input  logic 	  write,
	     output logic [31:0]  readdata,   
	     input  logic 	  read,
	     input  logic	  chipselect,
	     input  logic [3:0]   address,

	     // Avalon ST interface (sink) for input application data
	     //input logic [63:0]   app_in_data,
	     //input logic          app_in_startofpacket,
	     //input logic 	    app_in_endofpacket,
	     //input logic [2:0]    app_in_empty,
	     //input logic 	    app_in_valid,
	     //output logic 	    app_in_ready, // Check name is appropriate
	     
	     
	     // Avalon ST interface (source) for output application data
	     //output logic [63:0]  app_out_data,
	     //output logic         app_out_startofpacket,
	     //output logic 	  app_out_endofpacket,
	     //output logic [2:0]   app_out_empty,
	     //input logic 	  app_out_ready,  
	     //output logic         app_out_valid,
	   
	     // Avalon ST interface (sink) for input ethernet frames 
	     //input logic [63:0]   eth_in_data,
	     //input logic          eth_in_startofpacket,
	     //input logic 	  eth_in_endofpacket,
	     //input logic [2:0]    eth_in_empty,
	     //input logic 	  eth_in_valid,
	     //output logic 	  eth_in_ready, // Check name is appropriate
	     
	     
	     // Avalon ST interface (source) for output ethernet frame
	     output logic [31:0]  eth_out_data,
	     output logic         eth_out_startofpacket,
	     output logic 	  eth_out_endofpacket,
	     output logic [1:0]   eth_out_empty,
	     input logic 	  eth_out_ready,
	     output logic         eth_out_valid
	     );

	wire [7:0] 	addr_a;
	wire [31:0]	q_a;
	wire [31:0] 	data_a;
	wire 		wren_a;  
	wire [7:0] 	addr_b;
	wire [31:0]	q_b;
	wire [31:0] 	data_b;
	wire 		wren_b;  

	wire 		busy;
	wire 		ready;
	wire [431:0] 	header;

	logic [1:0] 	req_code;
	logic [7:0] 	id_in;
	logic [7:0] 	reply;
	logic [31:0] 	ip_src;
	logic [31:0] 	ip_dst;
	logic [47:0] 	mac_src;
	logic [47:0] 	mac_dst;	
	logic [15:0] 	port_src;
	logic [15:0] 	port_dst;

	always_ff @ (posedge clk) 
		begin
		if (rst)
			begin  
			req_code    <= 2'd0;
			id_in       <= 8'd0;
			ip_src      <= 32'd0;
			ip_dst      <= 32'd0;
			mac_src     <= 47'd0;
			mac_dst     <= 47'd0;
			port_src    <= 16'd0;
			port_dst    <= 16'd0;
			readdata    <= 32'd0; 
			end
		else if (write && chipselect) 
			case (address)
		  	4'h0 : req_code    	<= writedata[31:30];
		  	4'h1 : id_in      	<= writedata[31:24]; 
			// Address 2 is for reply and shouldn't be used 
		  	4'h3 : ip_src  		<= writedata;
		  	4'h4 : ip_dst   	<= writedata;
		   	4'h5 : mac_src[47:16] 	<= writedata;			  
			4'h6 : mac_src[15:0]    <= writedata[31:16];
		  	4'h7 : mac_dst[47:16]   <= writedata;
			4'h8 : mac_dst[15:0]    <= writedata[31:16]; 
		  	4'h9 : port_src 	<= writedata[31:16];
		  	4'ha : port_dst 	<= writedata[31:16];
			endcase

		else if(read && chipselect)
			begin
			case (address)
		  	4'h0 : readdata		<= {req_code, 30'd0};
		  	4'h1 : readdata  	<= {id_in, 24'd0};
		  	4'h2 : readdata 	<= {reply, 24'd0}; 
		  	4'h3 : readdata       	<= ip_src;
		  	4'h4 : readdata       	<= ip_dst;
		  	4'h5 : readdata	      	<= mac_src[47:16];
			4'h6 : readdata       	<= {mac_src[15:0], 16'd0};
			4'h7 : readdata 	<= mac_dst[47:16];
		  	4'h8 : readdata       	<= {mac_dst[15:0], 16'd0};
		 	4'h9 : readdata      	<= {port_src, 16'd0}; 
		  	4'ha : readdata         <= {port_dst, 16'd0}; 
			default : readdata 	<= 32'd0;
			endcase
			end
		end 

	Packetizer p0 	(.clk(clk), 
			 .rst(rst),
			 .done(busy),
			 .ready(ready),
			 .header(header),
			 .data(eth_out_data),
			 .p_start(eth_out_startofpacket),
			 .p_end(eth_out_endofpacket),
			 .empty(eth_out_empty),
			 .eth_ready(eth_out_ready),
			 .eth_valid(eth_out_valid));
	
	TOE_init t0 	(.data(data_a),
			 .wren(wren_a),
			 .addr(addr_a),
			 .q(q_a),
			 .*);

	Packet_builder pb0 (	.rst(rst),
				.clk(clk),
				.addr(addr_b),
				.ram_in(data_b),
				.ram_out(q_b),
				.wren(wren_b),
				.busy(busy),
				.ready(ready),
				.header(header)); 

     	RAM2 Connections_RAM (	.clock(clk),
				.address_a(addr_a),
				.address_b(addr_b),
				.q_a(q_a),
				.q_b(q_b),
				.data_a(data_a),
				.data_b(data_b),
				.wren_a(wren_a),
				.wren_b(wren_b)); 


endmodule
