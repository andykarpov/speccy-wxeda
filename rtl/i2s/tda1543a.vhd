-----------------------------------------------------------------[Rev.20110626]
-- I2S Master Controller (TDA1543A) Right-Justified Mode
-------------------------------------------------------------------------------
-- 56LE

-- STATE  000 001 002 003 004 005 006 007 008 009 010 011..   023 024 025 026 027 028 029 030 031 032 033 034 035..   047
--      ___  __________________________________  __  __  ..  __  __  __________________________________  __  __  ..  __  __  ____
-- DATA    \/               MSB                \/  \/  \/  \/  \/LS\/               MSB                \/  \/  \/  \/  \/LS\/   
--      ___/\__________________________________/\__/\__/\../\__/\__/\__________________________________/\__/\__/\../\__/\__/\____
--          -F- -F- -F- -F- -F- -F- -F- -F- -F- -E- -D-  .. -1- -0- -F- -F- -F- -F- -F- -F- -F- -F- -F- -E- -D-  .. -1- -0- 
--        _   _   _   _   _   _   _   _   _   _   _   _  ..   _   _   _   _   _   _   _   _   _   _   _   _   _  ..   _   _   _ 
-- BCK   | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |
--      _| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_
--           |
--          _|___________________________________________..________                                                         ______
-- WS      | |              LEFT                                   |                RIGHT                                  |
--      ___| |                                                     |_____________________________________________..________|
--           | SAMPLE OUT

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
entity tda1543a is
	Port ( 
		RESET	: in std_logic;
		CLK		: in std_logic;
		CS		: in std_logic;
        DATA_L	: in std_logic_vector (15 downto 0);
        DATA_R	: in std_logic_vector (15 downto 0);
		BCK		: out std_logic;
		WS		: out std_logic;
        DATA	: out std_logic );
end tda1543a;
 
architecture tda1543a_arch of tda1543a is
	signal data_i : std_logic_vector (47 downto 0);
begin
	process (RESET, CLK, CS)
	variable bit_cnt : integer range 0 to 47;
	begin
		if (RESET = '1' or CS = '0') then
			bit_cnt := 0;
			data_i <= (others => '0');
		elsif (CLK'event and CLK = '0') then
			if bit_cnt = 0 then
				data_i <= "00000000" & DATA_L & "00000000" & DATA_R;
				WS <= '1';
			elsif bit_cnt = 24 then
				WS <= '0';
				data_i <= data_i(46 downto 0) & '0';
			else
				data_i <= data_i(46 downto 0) & '0';
			end if;
			bit_cnt := bit_cnt + 1;
		end if;
	end process;

	DATA <= data_i(47);
	BCK <= CLK when CS = '1' else '1';

end tda1543a_arch;