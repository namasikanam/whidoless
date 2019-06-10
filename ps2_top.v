module ps2_top
(
    input CLOCK, RESET,
	 inout PS2_CLK, PS2_DAT,
	 output [2:0]lrm,
	 output reg[10:0]xs,
	 output reg[10:0]ys,
	 output [1:0]zs, // zs[1]表示方向，zs[0]表示动('1')还是没动('0')。
	 output Trig
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
