library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vga is
	port(
		reset: in std_logic;
		
		vga_needed_sram_addr: out std_logic_vector(19 downto 0); -- 地址
		vga_current_3: buffer integer range 0 to 2;
		
		x, y: buffer integer;
		
		r_in, g_in, b_in: in std_logic_vector(2 downto 0);
		r_out, g_out, b_out: out std_logic_vector(2 downto 0);
		
		clk25: in std_logic; -- 50MHz鏃堕挓杈撳叆
		hs, vs: out std_logic -- 琛屽悓姝ャ€佸満鍚屾淇″彿
	);
end entity;

architecture vga of vga is
	-- 640 x 480 @ 60 Hz, 使用25MHz时钟信号
	constant horizontal_visible_area: integer:= 640;
	constant horizontal_front_porch: integer:= 16;
	constant horizontal_sync_pulse: integer:= 96;
	constant horizontal_back_porch: integer:= 48;
	constant horizontal_whole_line: integer:= 800;
	constant horizontal_whole_address: integer:= 639/3 + 1;
	
	constant vertical_visible_area: integer:= 480;
	constant vertical_front_porch: integer:= 10;
	constant vertical_sync_pulse: integer:= 2;
	constant vertical_back_porch: integer:= 33;
	constant vertical_whole_line: integer:= 525;
	
	signal clk: std_logic;
	
	signal addr: integer;
begin
	clk <= clk25; -- 时钟信号
	
	-- 地址	
	addr <= y * horizontal_whole_address + x / 3;
	vga_needed_sram_addr <= conv_std_logic_vector(addr, vga_needed_sram_addr'length);

	-----------------------------------------------------------------------
	process(clk, reset)	--琛屽尯闂村儚绱犳暟锛堝惈娑堥殣鍖猴級
	begin
		if reset = '0' then
			x <= 0;
			vga_current_3 <= 0;
		elsif clk'event and clk = '1' then
			if x = horizontal_whole_line - 1 then
				x <= 0;
				vga_current_3 <= 0;
			else
				x <= x + 1;
				case vga_current_3 is
					when 0 => vga_current_3 <= 1;
					when 1 => vga_current_3 <= 2;
					when 2 => vga_current_3 <= 0;
				end case;
			end if;
		end if;
	end process;
	process(clk, reset)	--鍦哄尯闂磋鏁帮紙鍚秷闅愬尯锛
	begin
	 	if reset = '0' then
	  		y <= 0;
	  	elsif clk'event and clk = '1' then
			if x = horizontal_whole_line - 1 then
	    		if y = vertical_whole_line - 1 then
	     			y <= 0;
	    		else
	     			y <= y + 1;
	    		end if;
	   	end if;
	  	end if;
	end process;
 
	process(clk, reset)	--琛屽悓姝ヤ俊鍙蜂骇鐢
	begin
		if reset = '0' then
			hs <= '0';
		elsif clk'event and clk = '1' then
			if x >= horizontal_visible_area + horizontal_front_porch and x < horizontal_whole_line - horizontal_back_porch then
				hs <= '0';
			else
				hs <= '1';
		   end if;
		end if;
	end process;
	process(clk, reset)	--鍦哄悓姝ヤ俊鍙蜂骇鐢
	begin
	  	if reset = '0' then
	  		vs <= '0';
	  	elsif clk'event and clk = '1' then
	  		if y >= vertical_visible_area + vertical_front_porch and y < vertical_whole_line - vertical_back_porch then
	    		vs <= '0';
	  		else
	   		vs <= '1';
	  		end if;
	  	end if;
	end process;

	process(x, y, r_in, g_in, b_in)	--鑹插僵杈撳嚭
	begin
		if x >= 0 and y >= 0 and x < horizontal_visible_area and y < vertical_visible_area then
			r_out <= r_in;
			g_out <= g_in;
			b_out <= b_in;
		else
			r_out <= (others => '0');
			g_out <= (others => '0');
			b_out <= (others => '0');
		end if;
	end process;
end architecture;