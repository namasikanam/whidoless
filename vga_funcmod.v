module vga_funcmod 
(
    input CLOCK, RESET,
	 output VGA_HSYNC, VGA_VSYNC,
	 output [19:0]oAddr  // [20:10]X ,[9:0]Y
);
    parameter SA = 10'd96, SE = 10'd800;
	 parameter SO = 10'd2, SS = 10'd525;
	 
    reg [9:0]C1;
	 reg [9:0]C2;
	 reg rH,rV;
	 
	 always @ ( posedge CLOCK or negedge RESET )
	     if( !RESET )
		      begin
				    C1 <= 10'd0;
					 C2 <= 10'd0;
					 rH <= 1'b1;
					 rV <= 1'b1;
				end
		  else 
		      begin
				    
					 if( C1 == SE -1 ) rH <= 1'b0; 
				     else if( C1 == SA -1  ) rH <= 1'b1;
					 
					 if( C2 == SS -1 ) rV <= 1'b0;
					 else if( C2 == SO -1  ) rV <= 1'b1;
					 
					 if( C2 == SS -1 ) C2 <= 10'd0;
					 else if( C1 == SE -1 ) C2 <= C2 + 1'b1;
					 
				    if( C1 == SE -1 ) C1 <= 10'd0;
					 else C1 <= C1 + 1'b1;
					 
				end
				
	 reg [1:0]B1,B2,B3;
	 
    always @ ( posedge CLOCK or negedge RESET )
	     if( !RESET )
		      {  B3, B2, B1 } <= 6'b11_11_11;
		  else
		      begin
				    B1 <= { rH,rV };
				    B2 <= B1;
					 B3 <= B2;
				end	
    
	 assign { VGA_HSYNC, VGA_VSYNC } = B3;
	 assign oAddr = {C1,C2};
	 
endmodule
