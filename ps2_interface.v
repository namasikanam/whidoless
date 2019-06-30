// PS2扩展鼠标底层驱动
//
// 当鼠标触发事件时返回鼠标状态
//

module ps2_interface
(
    input CLOCK, RESET, // 时钟，RESET
	 inout PS2_CLK, PS2_DAT, // PS2时钟，PS2数据
	 output L, // 左键
	 output R, // 右键
	 output M, // 中键
	 output Xd, // 是否有X轴移动
	 output Yd, // 是否有Y轴移动
	 output Zd, // 是否有Z轴移动
	 output Trig, // 事件触发器
	 output [7:0]X, // X轴偏移
	 output [7:0]Y, // Y轴偏移
	 output Z // Z轴偏移
);
    wire [1:0]EnU1;
    
     ps2_init_funcmod U1
	 (
	     .CLOCK( CLOCK ),
		  .RESET( RESET ),
		  .PS2_CLK( PS2_CLK ), // < top
		  .PS2_DAT( PS2_DAT ), // < top
		  .oEn( EnU1 ) // > U2
	 );
	 
	 wire [31:0]DataU2;
	 
	  ps2_read_funcmod U2
	 (
	     .CLOCK( CLOCK ),
		  .RESET( RESET ),
		  .PS2_CLK( PS2_CLK ), // < top
		  .PS2_DAT( PS2_DAT ), // < top
		  .iEn( EnU1 ),      // < U1
		  .oTrig(Trig),
		  .oData( DataU2 )  // > U3
	 );

    assign L = DataU2[0];
    assign R = DataU2[1];
    assign M = DataU2[2];
	 assign Xd = DataU2[4];
	 assign Yd = DataU2[5];
	 assign Zd = DataU2[31];
    assign X = DataU2[15:8];
	 assign Y = DataU2[23:16];
	 assign Z = DataU2[24];
 		     
endmodule
