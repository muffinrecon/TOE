module Packetizer (	input logic 		clk, 
			input logic 		rst, 
			input logic [431:0]	header,
			input logic 		ready,
			output logic 		done,
			output logic [31:0]	data,
			output logic 		p_start,
			output logic 		p_end,
			output logic [1:0]	empty,
			input logic		eth_ready,
			output logic		eth_valid);
	
	logic [431:0] 	to_send;
	logic 		next_last;
	logic [3:0]	batch;
	assign 	next_last = ( batch == 4'd13); 

	enum logic [1:0] {s_IDLE, s_FIRST, s_BODY, s_END} s_state;

	always_ff @ (posedge clk)
		begin
		if (rst) to_send <= 432'd0;
		else if (ready) to_send <= header;
		end
 
	always_ff @ (posedge clk) 
		begin
		if (s_state == s_IDLE) batch <= 4'd0; 
		else if (eth_ready) batch <= batch + 4'd1; 
		end

	always_ff @ (posedge clk)
		begin
		if (rst) 
			begin 
			s_state <= s_IDLE;
			end 
		else 
			case (s_state) 
				s_IDLE 	: 
					begin
					if (eth_ready && (to_send != 432'd0)) s_state <= s_FIRST;
					else s_state <= s_IDLE; 
					end 
				s_FIRST :
					begin  
					if (eth_ready) s_state <= s_BODY;
					else s_state <= s_FIRST;
					end
				s_BODY	:
					begin
					if (eth_ready && next_last) s_state <= s_END;
					else s_state <= s_BODY; 
					end 
				s_END	:
					begin 
					if (eth_ready) s_state <= s_IDLE;
					else s_state <= s_END;
					end 
			endcase
		end

	assign p_start = (s_state == s_FIRST);
	assign p_end = (s_state == s_END);
	assign done = p_end;
	assign empty = (batch == 4'd14 ) ? 2'd2 : 2'd0;  
	assign eth_valid = (s_state != s_IDLE);

	always_comb
		case (batch)
			4'd0 :	 
				begin
				data[31:24] = to_send[7:0];
				data[23:16] = to_send[15:8];
				data[15:8] = to_send[23:16];
				data[7:0] = to_send[31:24];
				end
			4'd1:
				begin
				data[31:24] = to_send[39:32];
				data[23:16] = to_send[47:40];
				data[15:8] = to_send[55:48] ;
				data[7:0] = to_send[63:56]; 	
				end
			4'd2:
				begin
				data[31:24] = to_send[71:64];
				data[23:16] = to_send[79:72] ;
				data[15:8] = to_send[87:80];
				data[7:0] = to_send[95:88]; 	
				end
			4'd3:		
				begin
				data[31:24] = to_send[103:96];
				data[23:16] = to_send[111:104];
				data[15:8] = to_send[119:112];
				data[7:0] = to_send[127:120]; 	
				end
			4'd4:
				begin
				data[31:24] = to_send[135:128];
				data[23:16] = to_send[143:136];
				data[15:8] = to_send[151:144] ;
				data[7:0] = to_send[159:152]; 	
				end
			4'd5:
				begin
				data[31:24] = to_send[167:160];
				data[23:16] = to_send[175:168];
				data[15:8] = to_send[183:176];
				data[7:0] = to_send[191:184]; 	
				end
			4'd6:
				begin
				data[31:24] = to_send[199:192];
				data[23:16] = to_send[207:200];
				data[15:8] = to_send[215:208];
				data[7:0] = to_send[223:216]; 	
				end
			4'd7:
				begin
				data[31:24] = to_send[231:224];
				data[23:16] = to_send[239:232];
				data[15:8] = to_send[247:240];
				data[7:0] = to_send[255:248]; 	
				end
			4'd8:
				begin
				data[31:24] = to_send[263:256];
				data[23:16] = to_send[271:264];
				data[15:8] = to_send[279:272];
				data[7:0] = to_send[287:280]; 	
				end
			4'd9:
				begin
				data[31:24] = to_send[295:288];
				data[23:16] = to_send[303:296];
				data[15:8] = to_send[311:304];
				data[7:0] = to_send[319:312]; 	
				end
			4'd10:
				begin
				data[31:24] = to_send[327:320];
				data[23:16] = to_send[335:328];
				data[15:8] = to_send[343:336];
				data[7:0] = to_send[351:344]; 	
				end
			4'd11:
				begin
				data[31:24] = to_send[359:352];
				data[23:16] = to_send[367:360];
				data[15:8] = to_send[375:368];
				data[7:0] = to_send[383:376]; 	
				end
			4'd12:
				begin
				data[31:24] = to_send[391:384];
				data[23:16] = to_send[399:392];
				data[15:8] = to_send[407:400];
				data[7:0] = to_send[415:408]; 	
				end
			4'd13:
				begin
				data[31:24] = to_send[423:416];
				data[23:16] = to_send[431:424];
				data[15:8] = 8'd0;
				data[7:0] = 8'd0; 	
				end
			default:
				begin
				data[31:24] = 8'd0;
				data[23:16] = 8'd0;
				data[15:8] = 8'd0;
				data[7:0] = 8'd0; 	
				end
	endcase 
		
endmodule
