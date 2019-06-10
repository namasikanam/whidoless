library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity whidoless is
	port(
		clk: in std_logic; -- 100MHz时钟信号
		reset: in std_logic;
		
		-- SRAM
		ram_data: inout std_logic_vector(31 downto 0); -- 数据线
		ram_addr: out std_logic_vector(19 downto 0); -- 地址线
		ram_rw: out std_logic_vector(1 downto 0);
		
		-- VGA
		r_out, g_out, b_out: out std_logic_vector(2 downto 0);
		hs, vs: out std_logic;
		
		-- PS2
		mouse_reset: in std_logic;
		PS2_CLK, PS2_DAT: inout std_logic;
		
		-- SD Card
		SD_NCS, SD_CLK, SD_DI: out std_logic;
		SD_DOUT: in std_logic
	);
end entity;

architecture whidoless of whidoless is
	-- 显示屏的分辨率。
	-- 把涂鸦的分辨率降为 1024 / 4 * 768 / 3 = 256 * 256。
	constant W: integer:= 640;
	constant H: integer:= 480;
	constant R: integer:= 3; -- 涂鸦球的大小。
	constant NUMBER_OF_IMG: integer:= 20;
	constant NUMBER_OF_BLOCK: integer:= 600;
	
	signal clk50, clk25: std_logic;

	-- 鼠标
	component ps2_top
		port(
			CLOCK, RESET: in std_logic;
			PS2_CLK, PS2_DAT: inout std_logic;
			lrm: out std_logic_vector(2 downto 0);
			xs: out std_logic_vector(10 downto 0);
			ys: out std_logic_vector(10 downto 0);
			zs: out std_logic_vector(1 downto 0);
			Trig: out std_logic
		);
	end component;
	signal lrm: std_logic_vector(2 downto 0);
	signal xs, ys: std_logic_vector(10 downto 0);
	signal zs: std_logic_vector(1 downto 0);
	signal Trig: std_logic;
	signal mouse_x, mouse_y: integer;
	
	-- 屏幕
	component vga
		port(
			reset: in std_logic;
			
			addr_i: out std_logic_vector(19 downto 0); -- 地址
			addr_j: out std_logic_vector(1 downto 0);
			enable: out std_logic; -- '1'表示在消隐区，'0'表示不在。
			
			vga_x, vga_y: out integer;
			
			r_in, g_in, b_in: in std_logic_vector(2 downto 0);
			r_out, g_out, b_out: out std_logic_vector(2 downto 0);
			
			clk25: in std_logic; -- 50MHz鏃堕挓杈撳叆
			hs, vs: out std_logic -- 琛屽悓姝ャ€佸満鍚屾淇″彿
		);
	end component;
	signal enable: std_logic;
	signal addr: integer;
	signal vga_x, vga_y: integer;
	signal r_in, g_in, b_in: std_logic_vector(2 downto 0);
	
	-- SD Card
	component sdcard_top
		port(
			CLOCK_50, RESET: in std_logic;
			SD_NCS: out std_logic;
			SD_CLK: out std_logic;
			SD_DOUT: in std_logic;
			SD_DI: out std_logic;
			img_id: in std_logic_vector(9 downto 0);
			block_id: in std_logic_vector(9 downto 0);
			r: in std_logic;
			done: out std_logic;
			data: out std_logic_vector(4095 downto 0)
		);
	end component;
	signal sd_r: std_logic; -- 拉高表示向sd卡请求读取数据。
	signal sd_done: std_logic; -- 已经从sd卡里读出数据了
	signal sd_data: std_logic_vector(4095 downto 0);
	
	signal current_img_id: std_logic_vector(9 downto 0); -- 当前已经读好的img_id
	signal wanted_img_id: std_logic_vector(9 downto 0); -- 想读的img_id
	signal block_id: std_logic_vector(9 downto 0);
	signal sd_data_subscript: integer range 0 to 4095; -- 把sd卡数据的什么位置写进SRAM呢？
	signal current_sd_data: std_logic_vector(31 downto 0);
	signal sram_addr: std_logic_vector(19 downto 0); -- 把sd卡的数据写进SRAM的什么位置呢？
	
	signal sd_state: integer range 0 to 4; -- 读SD卡的状态机，其实也还没想好到底有几个状态。
	signal sram_w: std_logic; -- 控制SRAM，'0'表示在咸鱼，'1'表示告知SRAM：你可以把数据从SD卡中读到SRAM里了
	signal sram_done: std_logic; -- 模仿田哥的做法，感觉有个done信号还是蛮合理的。
	
	-- 时序逻辑
	signal state: std_logic_vector(3 downto 0);
	signal mouse_w: std_logic;
	
	signal addr_i: std_logic_vector(19 downto 0);
	signal addr_j: std_logic_vector(1 downto 0);
	signal vga_data: std_logic_vector(31 downto 0); -- r_in, g_in和b_in来自的地址
	
	signal paint_data0, paint_data1, paint_data2, paint_data3: std_logic_vector(7 downto 0);
	signal write_flag0, write_flag1, write_flag2, write_flag3: std_logic;
	
	-- 颜色
	signal right_click: std_logic;
	signal color: integer range 0 to 4; -- 涂鸦的颜色，0表示红，1表示绿，2表示蓝，3表示黑，4表示白。
	signal color_data: std_logic_vector(7 downto 0);
	
	-- type type_canvas is array (255 downto 0) of std_logic_vector(255 downto 0);
	-- signal canvas: type_canvas:= (others => (others => '0'));
begin
	-- 搞搞鼠标
	instance_of_mouse: ps2_top port map(
		CLOCK => clk50, RESET => mouse_reset,
		PS2_CLK => PS2_CLK, PS2_DAT => PS2_DAT,
		lrm => lrm,
		xs => xs, ys => ys, zs => zs,
		Trig => Trig
	);
	mouse_x <= conv_integer(unsigned(xs));
	mouse_y <= conv_integer(unsigned(ys));
	process(reset, right_click)
	begin
		if reset = '0' then
			color <= 0;
		elsif right_click'event and right_click = '1' then
			case color is
				when 0 => color <= 1;
				when 1 => color <= 2;
				when 2 => color <= 3;
				when 3 => color <= 4;
				when 4 => color <= 0;
			end case;
		end if;
	end process;
	process(color)
	begin
		case color is
			when 0 =>
				color_data <= "11000000";
			when 1 =>
				color_data <= "00011100";
			when 2 =>
				color_data <= "00000011";
			when 3 =>
				color_data <= "00000000";
			when 4 =>
				color_data <= "11011111";
		end case;
	end process;
	
	-- 搞搞屏幕
	instance_of_vga: vga port map(
		reset => reset,
		addr_i => addr_i, addr_j => addr_j,
		enable => enable,
		vga_x => vga_x, vga_y => vga_y,
		r_in => r_in, g_in => g_in, b_in => b_in,
		r_out => r_out, g_out => g_out, b_out => b_out,
		clk25 => clk25,
		hs => hs, vs => vs
	);
	process(mouse_x, mouse_y, vga_x, vga_y, addr_j) -- 在屏幕中搞出鼠标
	begin
		if (vga_x - mouse_x) * (vga_x - mouse_x) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then -- 目前是5 * 5 ，挺大的，以后肯定还会再改的……
			r_in <= color_data(7 downto 5);
			g_in <= color_data(4 downto 2);
			b_in <= color_data(1 downto 0) & "0";
		else
--			r_in <= "111";
--			g_in <= "000";
--			b_in <= "000";
			
			case addr_j is
				when "11" =>
					r_in <= vga_data(31 downto 29);
					g_in <= vga_data(28 downto 26);
					b_in <= vga_data(25 downto 24) & "0";
				when "10" =>
					r_in <= vga_data(23 downto 22) & "0";
					g_in <= vga_data(21 downto 21) & vga_data(19 downto 18);
					b_in <= vga_data(17 downto 16) & "0";
				when "01" =>
					r_in <= vga_data(15 downto 13);
					g_in <= vga_data(12 downto 10);
					b_in <= vga_data(9 downto 8) & "0";
				when "00" =>
					r_in <= vga_data(7 downto 5);
					g_in <= vga_data(4 downto 2);
					b_in <= vga_data(1 downto 0) & "0";
			end case;
		end if;
	end process;
	
	-- 搞搞SD卡
	instance_of_sdcard: sdcard_top port map(
		CLOCK_50 => clk50, RESET => reset,
		SD_NCS => SD_NCS, SD_CLK => SD_CLK, SD_DOUT => SD_DOUT, SD_DI => SD_DI,
		img_id => wanted_img_id, block_id => block_id,
		r => sd_r, done => sd_done, data => sd_data
	);
	process(reset, zs, clk, sd_done) -- 这里是滚轮触发换PPT。
		-- 处理的信号包括：
			-- 状态机：sd_state
			-- 是第几张图呢：wanted_img_id, current_img_id
			-- 是第几块呢：block_id
			-- 控制SD卡：sd_r
			-- 控制SRAM: sram_w
	begin
		if reset = '0' then -- 初始化的时候要来读第0张图呢！
			-- 是真正的初始化了！
			sd_r <= '0';
			sram_w <= '0';
			
			-- 切到state1，开始读图
			sd_state <= 1;
			current_img_id <= (others => '1');
			wanted_img_id <= (others => '0');
			
			block_id <= (others => '0');
			sram_addr <= (others => '0');
		elsif clk'event and clk = '1' then
			case sd_state is
				when 0 => -- 0当然是咸鱼态啦~
					if zs(0) = '1' then
						if zs(1) = '1' then
							if wanted_img_id /= "0000000000" then
								sd_state <= 1;
								wanted_img_id <= wanted_img_id - 1;
								
								block_id <= (others => '0');
								sram_addr <= (others => '0');
							end if;
						else
							if wanted_img_id /= NUMBER_OF_IMG - 1 then
								sd_state <= 1;
								wanted_img_id <= wanted_img_id + 1;
								
								block_id <= (others => '0');
								sram_addr <= (others => '0');
							end if;
						end if;
					end if;
				when 1 => -- 1的话，是要开始读块了！
					sd_r <= '1';
					sd_state <= 2;
				when 2 => -- 2的话，是在等待从SD卡中读块读好。
					if sd_done = '1' then
						sd_r <= '0';
						
						sd_data_subscript <= 0;
						
						sd_state <= 3;
					end if;
				when 3 => -- 开始写SRAM了！
					sram_w <= '1';
					sd_state <= 4;
				when 4 => -- 等待SRAM写好。
					if sram_done = '1' then
						sram_w <= '0';
						sram_addr <= sram_addr + 1;
						
						if sd_data_subscript /= 4064 then
							sd_data_subscript <= sd_data_subscript + 32;
							
							sd_state <= 3;
						else
							sd_data_subscript <= 0;
							
							if block_id /= NUMBER_OF_BLOCK then
								block_id <= block_id + 1;
								
								sd_state <= 1;
							else
								sd_state <= 0;
							end if;
						end if;
					end if;
			end case;
		end if;
	end process;
	current_sd_data <= sd_data(sd_data_subscript + 31 downto sd_data_subscript + 22) & sd_data(sd_data_subscript + 20 downto sd_data_subscript + 20) & "1" & sd_data(sd_data_subscript + 19 downto sd_data_subscript);
	
	-- 这是一个总的时序状态机。
	process(reset, clk)
		-- 控制信号：
		-- state
		-- 是否在写鼠标：mouse_w
		-- 是否写完了SD卡数据：sram_done
	begin
		if reset = '0' then
			state <= "0000";
			
			mouse_w <= '0';
			sram_done <= '0';
		elsif clk'event and clk = '1' then
			-- 分频
			clk50 <= not clk50;
			if state(0) = '0' then
				clk25 <= not clk25;
			end if;
			
			-- 对鼠标右键消毛刺
			right_click <= lrm(1);
			
			case state is
				when "0000" =>
					ram_rw <= "01";
					ram_addr <= addr_i;
					
					state <= "0001";
				when "0001" =>
					ram_data <= (others => 'Z');
					
					state <= "0010";
				when "0010" =>
					vga_data <= ram_data;
					
					state <= "0011";
				when "0011" => -- 在接下来的这个时钟周期里，第1个VGA像素应该被读出。
					ram_rw <= "11";
					
					if sram_w = '1' then
						ram_addr <= sram_addr;
						ram_data <= current_sd_data;
					elsif lrm(0) = '1' and enable = '1' then
						if (vga_x - mouse_x + 3) * (vga_x - mouse_x + 3) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then
							paint_data3 <= color_data;
							write_flag3 <= '1';
						else
							paint_data3 <= vga_data(31 downto 24);
							write_flag3 <= '0';
						end if;
						if (vga_x - mouse_x + 2) * (vga_x - mouse_x + 2) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then
							if color = 1 then
								paint_data2 <= "00101100";
							elsif color = 4 then
								paint_data2 <= "11101111";
							else
								paint_data2 <= color_data;
							end if;
							write_flag2 <= '1';
						else
							paint_data2 <= vga_data(23 downto 16);
							write_flag2 <= '0';
						end if;
						if (vga_x - mouse_x + 1) * (vga_x - mouse_x + 1) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then
							paint_data1 <= color_data;
							write_flag1 <= '1';
						else
							paint_data1 <= vga_data(15 downto 8);
							write_flag1 <= '0';
						end if;
						if (vga_x - mouse_x) * (vga_x - mouse_x) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then
							paint_data0 <= color_data;
							write_flag0 <= '1';
						else
							paint_data0 <= vga_data(7 downto 0);
							write_flag0 <= '0';
						end if;
						
						if write_flag0 = '1' or write_flag1 = '1' or write_flag2 = '1' or write_flag3 = '1' then
							mouse_w <= '1';
							
							ram_addr <= addr_i;
							ram_data <= paint_data3 & paint_data2 & paint_data1 & paint_data0;
						end if;
					end if;
					
					state <= "0100";
				when "0100" =>
					if mouse_w = '1' or sram_w = '1' then
						ram_rw <= "10";
					end if;
					
					state <= "0101";
				when "0101" =>
					state <= "0110";
				when "0110" =>
					state <= "0111";
				when "0111" =>
					state <= "1000";
				when "1000" =>
					state <= "1001";
				when "1001" =>
					state <= "1010";
				when "1010" =>
					state <= "1011";
				when "1011" =>
					state <= "1100";
				when "1100" =>
					state <= "1101";
				when "1101" =>
					if mouse_w = '1' or sram_w = '1' then
						ram_rw <= "11";
					end if;
					if sram_w = '1' then
						sram_done <= '1';
					end if;
					
					state <= "1110";
				when "1110" =>
					state <= "1111";
				when "1111" =>
					sram_done <= '0';
					
					mouse_w <= '0'; -- 在每个状态机周期(160ns)末尾清零
				
					state <= "0000";
			end case;
		end if;
	end process;
end architecture;