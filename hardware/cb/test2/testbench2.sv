module testbench2();

        logic           clk;
        logic           rst;
        logic [31:0]    writedata;
        logic           write;
        wire [31:0]     readdata;
        logic           read;
        logic           chipselect;
        logic [3:0]     address;

        TOE t0 (.*);

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

		// FIRST REQUEST
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
                address = 4'd5; //mac_src1
                writedata = 32'h33333333;
                
		@ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd6; //mac_src2
                writedata = 32'h33330000;

                @ (posedge clk);
                chipselect = 1'b0;
                write =1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //mac_dst1
                writedata = 32'h44444444;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //mac_dst2
                writedata = 32'h44440000;
                
		@ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;
                
		@ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //port_src
                writedata = 32'h5555;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd8; //port_dst
                writedata = 32'h6666_0000;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd0; //req
                writedata = 32'h4000_0000;

                @ (posedge clk);
                write = 1'b0;
                address = 4'd2;
                read = 1'b1;

                @ (posedge clk);
                wait(readdata != 32'd0);

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                read = 1'b0;
                address = 4'd0; //req
                writedata = 32'd0;


		// SECOND IDENTICAL REQUEST
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
                address = 4'd5; //mac_src1
                writedata = 32'h33333333;
                
		@ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd6; //mac_src2
                writedata = 32'h33330000;

                @ (posedge clk);
                chipselect = 1'b0;
                write =1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //mac_dst1
                writedata = 32'h44444444;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //mac_dst2
                writedata = 32'h44440000;
                
		@ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;
                
		@ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd7; //port_src
                writedata = 32'h5555;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd8; //port_dst
                writedata = 32'h6666_0000;

                @ (posedge clk);
                chipselect = 1'b0;
                write = 1'b0;

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                address = 4'd0; //req
                writedata = 32'h4000_0000;

                @ (posedge clk);
                write = 1'b0;
                address = 4'd2;
                read = 1'b1;

                @ (posedge clk);
                @ (posedge clk);
                wait(readdata != 32'd0);

                @ (posedge clk);
                chipselect = 1'b1;
                write = 1'b1;
                read = 1'b0;
                address = 4'd0; //req
                writedata = 32'd0;

                end

endmodule
