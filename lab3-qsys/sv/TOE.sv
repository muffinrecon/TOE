/*
 * Module containing all interfaces for the TOE 
 *
 * Clementine Barbet
 * cb3022
 */

module TOE ( input  logic         clk,
	     input  logic 	  reset,

	     // Avalon MM slave interface
	     input  logic [31:0]  writedata,
	     input  logic 	  write,
	     output logic [31:0]  readdata,   
	     input  logic 	  read,
	     input  logic	  chipselect,
	     input  logic [3:0]   address

	     // Avalon ST interface (sink) for input application data
	     //input logic [63:0]   app_in_data,
	     //input logic          app_in_startofpacket,
	     //input logic 	  app_in_endofpacket,
	     //input logic [2:0]    app_in_empty,
	     //input logic 	  app_in_valid,
	     //output logic 	  app_in_ready, // Check name is appropriate
	     
	     
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
	     //output logic [63:0]  eth_out_data,
	     //output logic         eth_out_startofpacket,
	     //output logic 	  eth_out_endofpacket,
	     //output logic [2:0]   eth_out_empty,
	     //input logic 	  eth_out_ready,
	     //output logic         eth_out_valid
	     );

		 
	TOE_init t0(.*);
      
endmodule
