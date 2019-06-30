// PS2扩展鼠标高层驱动
//
// 直接显示鼠标坐标和状态
//

module ps2_top
(
    input CLOCK, RESET, // 时钟，RESET
	 inout PS2_CLK, PS2_DAT, // PS2时钟，PS2数据
	 output [2:0]lrm, // 左键右键中建状态
	 output reg[10:0]xs, // X轴坐标
	 output reg[10:0]ys, // Y轴坐标
	 output [1:0]zs, // Z轴偏移
	 output Trig // 事件触发器
);

    parameter XMAX = 11'd639;
	 parameter YMAX = 11'd479;
    parameter XINIT = 11'd320;
	 parameter YINIT = 11'd240;

    wire L, R, M, Xd, Yd, Zd;
	 wire [7:0]X;
	 wire [7:0]Y;
	 wire Z;

     ps2_interface U1
	 (
	     .CLOCK( CLOCK ),
		  .RESET( RESET ),
		  .PS2_CLK( PS2_CLK ),
		  .PS2_DAT( PS2_DAT ),
		  .L( L ),
		  .R( R ),
		  .M( M ),
		  .Xd( Xd ),
		  .Yd( Yd ),
		  .Zd( Zd ),
		  .Trig( Trig ),
		  .X( X ),
		  .Y( Y ),
		  .Z( Z )
	 );
	 
	 assign lrm = {M, R, L};
	 
	 always @(posedge Trig or negedge RESET)
	 begin
	     if (!RESET)
		  begin
		      xs <= XINIT;
				ys <= YINIT;
		  end
		  else
		  begin
		      if (Xd == 0)
				begin
				    if (XMAX - xs > {3'b0, X})
					     xs <= xs + {3'b0, X};
					 else
					     xs <= XMAX;
				end
				else
				begin
				    if (xs > {3'b0, -X})
					     xs <= xs + {3'b111, X};
					 else
					     xs <= 11'b0;
				end
				
				if (Yd == 0)
				begin
				    if (ys > {3'b0, Y})
					     ys <= ys - {3'b0, Y};
					 else
					     ys <= 11'b0;
				end
				else
				begin
				    if (YMAX - ys > {3'b0, -Y})
					     ys <= ys - {3'b111, Y};
					 else
					     ys <= YMAX;
				end
		  end
	 end
	 
	 assign zs = {Zd, Z};
	 
endmodule
