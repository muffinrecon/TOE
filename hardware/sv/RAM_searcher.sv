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
    reg [6:0] counter;
    reg wren;
    reg [7:0] addr;
    reg not_found;
    wire [144:0] data_out;
    reg [144:0] data_in;
    RAM RAM_Storage (.address (addr), .clock (clk), .data(data_in), .wren(wren), .q(data_out));
    
    always_ff @ (posedge clk)
        begin
        //store the data into data_in
        data_in[144:121] <= rs_mac_src;
        data_in[120:97] <= rs_mac_dst;
        data_in[96:65] <= rs_ip_src;
        data_in[64:33] <= rs_ip_dst;
        data_in[32:17] <= rs_port_src;
        data_in[16:1] <= rs_port_dst;
        data_in[0] <= 1'b1; //valid bit
        if (rs_rst) // reset signals
            begin
                counter <= 7'b0; 
                not_found <= 1'b1;
                wren <= 1'b0;
                addr <= 8'b0;
                con_existed <= 1'b0;
                rs_id_out <= 8'b0;
                rs_done <= 1'b0;
            end
        //check if there is a connection
        else if(rs_rq == 2'b1)//assuming rs_rq==1 means reqest to initialize a new connection
            begin
                //go through the RAM.
                //setting loop to max of 250, there will be error with more than 250
                for (int i=0;i<=counter;i++)
                begin
                    addr = i;
                    //found exisiting connection
                    if (data_out == data_in)
                    begin
                        wren <= 1'b0; //disable wren
                        rs_id_out <= addr -1 ; // assign ID as addr
                        not_found <= 1'b0; //set not_found to false
                        rs_error <= 7'b1; //there is an exsiting connection
                        rs_done <= 1b'1; //done
                    end
                end
                addr = rs_id_out;//not sure of this
                //after looping through RAM
                //not found exisiting connection
                #80ns;//wait the for loop to be done
                if (not_found)    
                begin
                    wren <= 1'b1; //enable wren
                    counter <= counter + 1'b1; //counter ++;
                    rs_id_out <= counter; //return ID as counter
                    rs_error <= 7'b11; //no exsiting connection
                    //not_found <= 1'b0; //reset not_found to false
                end
            end
        //write to RAM,
        if(wren)
            begin
                addr = rs_id_out;//RAM address as ID
                rs_done <= 1b'1; //done
            end
        end
    
endmodule
