// VGA显示高层驱动
//
//
// 使用sram作为缓冲输出9位颜色图像
//

module vga
(
    input reset, // RESET
	 output reg[20:0]vga_needed_sram_addr, // SRAM地址
	 output integer vga_current_3, // 颜色通道选择
	 output integer x, // x坐标
	 output integer y, // y坐标
	 input [2:0]r_in, // 红色通道输入
	 input [2:0]g_in, // 绿色通道输入
	 input [2:0]b_in, // 蓝色通道输入
	 output [2:0]r_out, // 红色通道输出
	 output [2:0]g_out, // 绿色通道输出
	 output [2:0]b_out, // 蓝色通道输出
     input clk25, // 时钟
	 output hs, // 垂直扫描
	 output vs // 水平扫描
);

	 wire [19:0]AddrU2;
	 
	 vga_funcmod U2
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
	 
	 vga_ctrlmod U4
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
