// VGA显示控制驱动
//
// 修改相关参数可以调整刷新率和分辨率
//
// 关于刷新率和分辨率和对应参数的对应关系请参考网上资料
// 如果显示出现偏移，请通过修改XOFF和YOFF进行微调
//

module vga_ctrlmod
(
    input CLOCK, RESET, // 时钟和RESET
	 output [8:0]VGAD, // 输出颜色
	 output [20:0]oAddr, // 输出地址
	 input [8:0]iData, // 输入颜色
	 input [19:0]iAddr // 输入地址
);
	 parameter SA = 10'd96, SB = 10'd48, SC = 10'd640, SD = 10'd16, SE = 10'd800;
	 parameter SO = 10'd2, SP = 10'd33, SQ = 10'd480, SR = 10'd10, SS = 10'd525;
	 
	 // Height , width, x-offset and y-offset
	 parameter XSIZE = 10'd640, YSIZE = 10'd480, XOFF = 10'd5, YOFF = 10'd0; 
    
	 wire isX = ( (iAddr[19:10] >= SA + SB - XOFF ) && ( iAddr[19:10] <= SA + SB - XOFF + XSIZE -1) );
	 wire isY = ( (iAddr[9:0] >= SO + SP + YOFF ) && ( iAddr[9:0] <= SO + SP + YOFF + YSIZE -1) );
	 wire isReady = isX & isY;
	 
	 wire [9:0] x = iAddr[19:10] + XOFF - SA - SB; 
	 wire [9:0] y = iAddr[9:0] + YOFF - SO - SP;
	 
	 reg [19:0]D1;
	 reg [8:0]rVGAD;
	 
     always @ ( posedge CLOCK or negedge RESET )
	     if( !RESET )
		      begin
				    D1 <= 20'd0;
				    rVGAD <= 9'd0;
				end
			else
			   begin
				
				    // step 1 : compute data address and index-n
					 if( isReady )
					     D1 <= {y , x}; 
					 else
					     D1 <= 20'd0;
					 
					 // step 2 : reading data from rom
					 // but do-nothing
					 
					 // step 3 : assign RGB_Sig
					 rVGAD <= isReady ? iData : 9'b000000000;
					 
				end
				
	assign VGAD = rVGAD;
	assign oAddr = D1;

endmodule
