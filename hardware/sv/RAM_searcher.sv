//Note: before setting rs_rq == 1, meaning initialzing a new connection, input data rs_ip_src etc.. has to be set for at least 2 clock 
//cycles in advacne. This was tested in ModelSim to make sure correct timing.

//deletion of a connection not done yet

module RAM_searcher (input logic rs_clk,
			input logic rs_rst,
			input logic [1:0] rs_rq,
			input logic [7:0] rs_id_in,
			input logic [31:0] rs_ip_src,
			input logic [31:0] rs_ip_dst,
			input logic [23:0] rs_mac_src,
			input logic [23:0] rs_mac_dst,
			input logic [15:0] rs_port_src,
			input logic [15:0] rs_port_dst,
			output logic [7:0]    rs_error,
			output logic rs_done,
			output logic [7:0]    rs_id_out);

//To be implemented by Qi
    reg [6:0] counter;
    reg wren;
    reg [7:0] addr;
    reg not_found;
    wire [144:0] data_out;
    reg [144:0] data_in;
     logic delete;
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
                rs_id_out <= 8'b0;
                rs_done <= 1'b0;
                     delete <= 1'b0;
            end
        //check if there is a connection
        else if(rs_rq == 2'b01)//assuming rs_rq==1 means reqest to initialize a new connection
            begin
                //go through the RAM.
                //setting loop to max of 250, there will be error with more than 250
                for (int i=0;i<=counter;i++)
                begin
                    addr = i;
                    //found exisiting connection
                    if (data_out[144:1] == data_in [144:1] && data_out[0] == 1'b1)
                    begin
                        wren <= 1'b0; //disable wren
                        rs_id_out <= addr -1 ; // assign ID as addr
                        not_found <= 1'b0; //set not_found to false
                        rs_error <= 7'b1; //there is an exsiting connection
                        rs_done <= 1'b1; //done
                    end
                          //else if (data_out[144:1] == data_in [144:1] && data_out[0] == 1'b0)
                          //begin
                                
                          //end
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
                          addr = counter;//RAM address as ID
                    //not_found <= 1'b0; //reset not_found to false
                end
            end
          else if (rs_rq == 2'b10)//assuming rs_rq==10 means reqest to delete a new connection
                begin
                    addr = rs_id_in;
                    delete <= 1'b1;
                    wren <= 1'b1;
                    data_in <= data_out;
                    data_in[0] <= 1'b0; //valid bit
                end
        //write to RAM,
          if (wren && delete)
                begin
                    rs_done <= 1'b1; //done
                end
        else if(wren)
            begin
                rs_done <= 1'b1; //done
            end
        end
    
endmodule
