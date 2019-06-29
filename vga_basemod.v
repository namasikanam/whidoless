module vga
(
    input reset,
	 output reg[20:0]vga_needed_sram_addr,
	 output integer vga_current_3,
	 output integer x,
	 output integer y,
	 input [2:0]r_in,
	 input [2:0]g_in,
	 input [2:0]b_in,
	 output [2:0]r_out,
	 output [2:0]g_out,
	 output [2:0]b_out,
    input clk25,
	 output hs,
	 output vs
);

	 wire [19:0]AddrU2; // [20:10]X ,[9:0]Y
	 
	 vga_funcmod U2    // 640 * 480 @ 60Hz
	 (
	   .CLOCK( clk25 ), 
	   .RESET( reset ),
	   .VGA_HSYNC( hs ), 
	   .VGA_VSYNC( vs ),
	   .oAddr( AddrU2 )
	 );			 
	 
	 wire [8:0]DataU3;
	 
	 assign DataU3[8:6] = r_in;
	 assign DataU3[5:3] = g_in;
	 assign DataU3[2:0] = b_in;
    
	 wire [19:0]AddrU4;
	 wire [8:0] VGAD;
	 
	 vga_ctrlmod U4  // 128 * 96 * 16bit, X0,Y0
	 (
	     .CLOCK( clk25 ),
		  .RESET( reset ),
		  .VGAD( VGAD ),
		  .iData( DataU3 ),
	     .oAddr( AddrU4 ),
	     .iAddr( AddrU2 )
	 );
	 
	 assign r_out = VGAD[8:6];
	 assign g_out = VGAD[5:3];
	 assign b_out = VGAD[2:0];
	 
	 always @(*) begin
	     x = {22'd0,AddrU4[9:0]};
		  y = {22'd0,AddrU4[19:10]};
		  vga_needed_sram_addr = (y * 214 + x / 3);
	 end
	 
	 always @(posedge clk25) begin
	     if (!reset) begin
		      vga_current_3 <= 0;
		  end
		  else begin
				case (vga_current_3)
					 0: vga_current_3 <= 1;
					 1: vga_current_3 <= 2;
					 2: vga_current_3 <= 0;
				endcase
		  end
	 end
	 
endmodule
