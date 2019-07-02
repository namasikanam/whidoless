-- 主控制程序

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity whidoless is
	port(
		clk: in std_logic; -- 100MHz时钟信号
		reset: in std_logic; -- reset信号
		
		-- SRAM
		ram_data: inout std_logic_vector(31 downto 0); -- 数据线
		ram_addr: out std_logic_vector(19 downto 0); -- 地址线
		ram_rw: out std_logic_vector(1 downto 0); -- 读写控制信号
		ram_cs: out std_logic; -- 控制信号
		
		-- VGA
		r_out, g_out, b_out: out std_logic_vector(2 downto 0); -- VGA输出信号
		hs, vs: out std_logic; -- VGA控制信号
		
		-- PS2
		mouse_reset: in std_logic; -- 鼠标重置信号
		PS2_CLK, PS2_DAT: inout std_logic; -- 鼠标信号
		
		-- SD Card
		SD_NCS, SD_CLK, SD_DI: out std_logic; -- SD卡控制信号
		SD_DOUT: in std_logic -- SD卡输出信号
	);
end entity;

architecture whidoless of whidoless is
	constant W: integer:= 640;
	constant H: integer:= 480;
	constant R: integer:= 3; -- 涂鸦球的大小。
	constant NUMBER_OF_IMG: integer:= 20;
	constant NUMBER_OF_BLOCK: integer:= 856;
	constant MAX_VALID_SD_SUBSCRIPT: integer:= 3213;
	constant LENGTH_OF_SD_WORD: integer:= 27;
	constant W_WHOLE: integer:= 800;
	
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
			
			vga_needed_sram_addr: out std_logic_vector(19 downto 0); -- 地址
			vga_current_3: buffer integer range 0 to 2;
			
			x, y: out integer;
			
			r_in, g_in, b_in: in std_logic_vector(2 downto 0);
			r_out, g_out, b_out: out std_logic_vector(2 downto 0);
			
			clk25: in std_logic;
			hs, vs: out std_logic
		);
	end component;
	signal enable: std_logic;
	signal addr: integer;
	signal vga_x, vga_y: integer;
	signal vga_x0, vga_y0, vga_x1, vga_y1, vga_x2, vga_y2: integer;
	signal r_in, g_in, b_in: std_logic_vector(2 downto 0);
	
	-- SD Card
	component sdcard_top
		port(
			CLOCK_50, RESET: in std_logic;
			SD_NCS, SD_CLK: out std_logic;
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
	signal sd_data: std_logic_vector(4095 downto 0); -- 从sd卡读到的数据
	
	signal wanted_img_id: std_logic_vector(9 downto 0); -- 想读的img_id
	signal block_id: std_logic_vector(9 downto 0); -- 想读的block_id
	signal sd_data_subscript: integer range 0 to 4000; -- 把sd卡数据的什么位置写进SRAM呢？
	signal current_sd_data: std_logic_vector(31 downto 0); -- 当前从sd卡里写入SRAM中的数据。
	signal sram_addr: std_logic_vector(19 downto 0); -- 把sd卡的数据写进SRAM的什么位置呢？
	
	signal sd_state: integer range 0 to 4; -- 读SD卡的状态机，其实也还没想好到底有几个状态。
	signal sram_w: std_logic; -- 控制SRAM，'0'表示在咸鱼，'1'表示告知SRAM：你可以把数据从SD卡中读到SRAM里了
	signal sram_done: std_logic; -- done信号表示已经成功把sd卡中的数据写入SRAM中了
	
	-- 时序逻辑
	signal state: std_logic_vector(3 downto 0); -- 状态机的状态
	signal mouse_w: std_logic; -- 鼠标是否按住了，按住的话就表示需要涂鸦了
	
	signal vga_needed_sram_addr: std_logic_vector(19 downto 0); -- VGA需要读取的SRAM的地址
	signal vga_current_3: integer range 0 to 2; -- 一次从SRAM中读3个VGA pixel需要的数据，这个表示现在VGA读到的是第几个pixel
	signal vga_data: std_logic_vector(31 downto 0); -- r_in, g_in和b_in来自的地址
	
	signal paint_data0, paint_data1, paint_data2: std_logic_vector(8 downto 0); -- 涂鸦数据。
	signal write_flag0, write_flag1, write_flag2: std_logic; -- 一次写入的3个VGA pixel是否位于涂鸦球中。
	
	-- 颜色
	signal right_click: std_logic; -- 鼠标右键点击信号
	type ENUM_COLOR is (Red, Green, Blue, Black, White);
	signal color: ENUM_COLOR; -- 当前涂鸦的颜色
	signal color_data: std_logic_vector(8 downto 0); -- 当前涂鸦颜色对应的数据
	
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
			color <= Red;
		elsif right_click'event and right_click = '1' then
			case color is
				when Red => color <= Green;
				when Green => color <= Blue;
				when Blue => color <= White;
				when White => color <= Black;
				when Black => color <= Red;
			end case;
		end if;
	end process;
	process(color)
	begin
		case color is
			when Red => color_data <= "111000000";
			when Green => color_data <= "000111000";
			when Blue => color_data <= "000000111";
			when White => color_data <= "000000000";
			when Black => color_data <= "111111111";
		end case;
	end process;
	
	-- 搞搞屏幕
	instance_of_vga: vga port map(
		reset => reset,
		vga_needed_sram_addr => vga_needed_sram_addr, vga_current_3 => vga_current_3,
		x => vga_x, y => vga_y,
		r_in => r_in, g_in => g_in, b_in => b_in,
		r_out => r_out, g_out => g_out, b_out => b_out,
		clk25 => clk25,
		hs => hs, vs => vs
	);
	process(mouse_x, mouse_y, vga_x, vga_y, vga_data, color_data, vga_current_3) -- 在屏幕中搞出鼠标
	begin
		if (vga_x - mouse_x) * (vga_x - mouse_x) + (vga_y - mouse_y) * (vga_y - mouse_y) <= R * R then
			r_in <= color_data(8 downto 6);
			g_in <= color_data(5 downto 3);
			b_in <= color_data(2 downto 0);
		else
			case vga_current_3 is
				when 2 =>
					r_in <= vga_data(27 downto 25);
					g_in <= vga_data(24 downto 22);
					b_in <= vga_data(21 downto 21) & vga_data(19 downto 18);
				when 1 =>
					r_in <= vga_data(17 downto 15);
					g_in <= vga_data(14 downto 12);
					b_in <= vga_data(11 downto 9);
				when 0 =>
					r_in <= vga_data(8 downto 6);
					g_in <= vga_data(5 downto 3);
					b_in <= vga_data(2 downto 0);
			end case;
		end if;
	end process;
	process(reset, clk)
	begin
		if reset = '0' then
			vga_x0 <= 0;
			vga_y0 <= 0;
			vga_x1 <= 1;
			vga_y1 <= 0;
			vga_x2 <= 2;
			vga_y2 <= 0;
		elsif clk'event and clk = '1' then
			vga_x0 <= vga_x;
			vga_y0 <= vga_y;
			
			vga_x1 <= vga_x0 + 1;
			vga_y1 <= vga_y;
			
			vga_x2 <= vga_x0 + 2;
			vga_y2 <= vga_y;
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
			-- 是第几张图呢：wanted_img_id
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
			wanted_img_id <= (others => '0');
			
			block_id <= (others => '0');
			sram_addr <= (others => '0');
		elsif clk'event and clk = '1' then
			case sd_state is
				when 0 => -- 0当然是咸鱼态啦~
					if Trig = '1' and zs(0) = '1' then
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
						
						-- SRAM数据位+1
						sram_addr <= sram_addr + 1;
						
						-- SD卡数据位+1
						if sd_data_subscript /= MAX_VALID_SD_SUBSCRIPT then
							sd_data_subscript <= sd_data_subscript + LENGTH_OF_SD_WORD;
							
							sd_state <= 3;
						else
							sd_data_subscript <= 0;
							
							if block_id /= NUMBER_OF_BLOCK - 1 then
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
	
	current_sd_data <= "0000" & sd_data(sd_data_subscript + 26 downto sd_data_subscript + 20) & "0" & sd_data(sd_data_subscript + 19 downto sd_data_subscript);-- 跳过第20位。
	
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
			
			ram_cs <= '1';
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
					ram_cs <= '0';
					
					ram_addr <= vga_needed_sram_addr;
					ram_data <= (others => 'Z');
					
					state <= "0001";
				when "0001" =>
					vga_data <= ram_data;
					
					state <= "0010";
				when "0010" =>
					
					state <= "0011";
				when "0011" => -- 在接下来的这个时钟周期里，第1个VGA像素应该被读出。
					ram_rw <= "11";
					ram_cs <= '1';
					
					if sram_w = '1' then
						ram_addr <= sram_addr;
						ram_data <= current_sd_data;
					elsif lrm(0) = '1' then
						if vga_x2 < W and vga_y2 < H and (vga_x2 - mouse_x) * (vga_x2 - mouse_x) + (vga_y2 - mouse_y) * (vga_y2 - mouse_y) <= R * R then
							paint_data2 <= color_data;
							write_flag2 <= '1';
						else
							paint_data2 <= vga_data(27 downto 21) & vga_data(19 downto 18);
							write_flag2 <= '0';
						end if;
						if vga_x1 < W and vga_y1 < H and (vga_x1 - mouse_x) * (vga_x1 - mouse_x) + (vga_y1 - mouse_y) * (vga_y1 - mouse_y) <= R * R then
							paint_data1 <= color_data;
							write_flag1 <= '1';
						else
							paint_data1 <= vga_data(17 downto 9);
							write_flag1 <= '0';
						end if;
						if vga_x0 < W and vga_y0 < H and (vga_x0 - mouse_x) * (vga_x0 - mouse_x) + (vga_y0 - mouse_y) * (vga_y0 - mouse_y) <= R * R then
							paint_data0 <= color_data;
							write_flag0 <= '1';
						else
							paint_data0 <= vga_data(8 downto 0);
							write_flag0 <= '0';
						end if;
						
						if (write_flag0 = '1' or write_flag1 = '1' or write_flag2 = '1') and vga_needed_sram_addr >= 2 then
							mouse_w <= '1';
							
							ram_addr <= vga_needed_sram_addr - 2;
							ram_data <= "0000" & paint_data2(8 downto 2) & "0" & paint_data2(1 downto 0) & paint_data1 & paint_data0; -- 存入SRAM时跳过第20位。
						end if;
					end if;
					
					state <= "0100";
				when "0100" =>
					state <= "0101";
				when "0101" =>
					if mouse_w = '1' or sram_w = '1' then
						ram_rw <= "10";
						ram_cs <= '0';
					end if;
					state <= "0110";
				when "0110" =>
					state <= "0111";
				when "0111" =>
					state <= "1000";
				when "1000" =>
					state <= "1001";
				when "1001" =>
					if mouse_w = '1' or sram_w = '1' then
						ram_rw <= "11";
						ram_cs <= '1';
					end if;
					state <= "1010";
				when "1010" =>
					if sram_w = '1' then
						sram_done <= '1';
					end if;
					state <= "1011";
				when "1011" =>
					sram_done <= '0';
					
					mouse_w <= '0'; -- 在每个状态机周期(160ns)末尾清零
					
					state <= "0000";
				when others => null;
			end case;
		end if;
	end process;
end architecture;