-------------------------------------------------------------------[23.03.2015]
-- Speccy WXEDA Version 1.0 
-- https://github.com/andykarpov/speccy-wxeda
-- Ported by Andy Karpov from u16-speccy project by MVV
-------------------------------------------------------------------------------

-- http://zx.pk.ru/showthread.php?t=13875

-- Copyright (c) 2011-2014 MVV
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without 
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

-- SDRAM map:
-- 4 3210 9876 5432 1098 7654 3210
-- 0 00xx_xxxx xxxx_xxxx xxxx_xxxx	0000000-03FFFFF		RAM 	4MB
-- 0 xxxx_xxxx xxxx_xxxx xxxx_xxxx	0400000-0FFFFFF		-----------
-- 1 0000_0xxx xxxx_xxxx xxxx_xxxx	1000000-107FFFF		divMMC 512K (reserved)
-- 1 0000_1000 00xx_xxxx xxxx_xxxx	1080000-1003FFF		GLUK	16K (SPECCY.ROM)
-- 1 0000_1000 01xx_xxxx xxxx_xxxx	1084000-1007FFF		TR-DOS	16K (SPECCY.ROM)
-- 1 0000_1000 10xx_xxxx xxxx_xxxx	1088000-100BFFF		ROM'86	16K (SPECCY.ROM)
-- 1 0000_1000 11xx_xxxx xxxx_xxxx	108C000-100FFFF		ROM'82	16K (SPECCY.ROM)
-- 1 0000_1001 000x_xxxx xxxx_xxxx	1090000-1091FFF		divMMC	 8K (SPECCY.ROM)
-- 1 0000_1001 001x_xxxx xxxx_xxxx	1092000-1093FFF		test128	 8K (SPECCY.ROM)

entity speccy is
port (
	-- Clock (48MHz)
	CLK_48MHZ		: in std_logic;
	
	-- SDRAM (32MB 16x16bit)
	SDRAM_D			: inout std_logic_vector(15 downto 0); -- sdram data bus  
	SDRAM_A			: out std_logic_vector(12 downto 0); -- sdram address bus 
	SDRAM_BA		: out std_logic_vector(1 downto 0); -- sdram bank address 
	SDRAM_CLK		: out std_logic; -- sdram clock
	SDRAM_DQML		: out std_logic; -- sdram low data byte mask
	SDRAM_DQMH		: out std_logic; -- sdram high data byte mask
	SDRAM_WE_n		: out std_logic; -- sdram write enable
	SDRAM_CAS_n		: out std_logic; -- sdram column address strobe
	SDRAM_RAS_n		: out std_logic; -- sdram row address strobe
	SDRAM_CKE		: out std_logic; -- sdram clock enable
	SDRAM_CS_N		: out std_logic; -- sdram chip enable
	
	-- SPI FLASH (W25Q32)
	DATA0			: in std_logic;  -- Flash MOSI
	NCSO			: out std_logic; -- Flash CS
	DCLK			: out std_logic; -- Flash SCLK
	ASDO			: out std_logic; -- Flash MISO

	-- VGA
	VGA_R			: out std_logic_vector(4 downto 0);
	VGA_G			: out std_logic_vector(5 downto 0);
	VGA_B			: out std_logic_vector(4 downto 0);
	VGA_HS			: out std_logic;
	VGA_VS			: out std_logic;

	-- External I/O
	DAC_OUT_L		: out std_logic; -- Audio out L
	DAC_OUT_R		: out std_logic; -- Audio out R
	KEYS			: in std_logic_vector(3 downto 0); -- Physical push buttons
	BUZZER			: out std_logic; -- Pieso buzzer
	
	-- UART
	UART_RXD		: inout std_logic;
	UART_TXD 		: inout std_logic;
	
	-- PS/2 Keyboard
	PS2_CLK			: inout std_logic;
	PS2_DAT  		: inout std_logic;
	
	-- SD/MMC Card
	SD_SO			: in std_logic;
	SD_SI			: out std_logic;
	SD_CLK			: out std_logic;
	SD_CS_n			: out std_logic);
	
end speccy;

architecture rtl of speccy is

-- CPU0
signal cpu0_reset_n	: std_logic;
signal cpu0_clk		: std_logic;
signal cpu0_a_bus	: std_logic_vector(15 downto 0);
signal cpu0_do_bus	: std_logic_vector(7 downto 0);
signal cpu0_di_bus	: std_logic_vector(7 downto 0);
signal cpu0_mreq_n	: std_logic;
signal cpu0_iorq_n	: std_logic;
signal cpu0_wr_n	: std_logic;
signal cpu0_rd_n	: std_logic;
signal cpu0_int_n	: std_logic;
signal cpu0_inta_n	: std_logic;
signal cpu0_m1_n	: std_logic;
signal cpu0_rfsh_n	: std_logic;
signal cpu0_ena		: std_logic;
signal cpu0_mult	: std_logic_vector(2 downto 0);
signal cpu0_mem_wr	: std_logic;
signal cpu0_mem_rd	: std_logic;
signal cpu0_nmi_n	: std_logic;
-- Memory
signal ram_a_bus	: std_logic_vector(11 downto 0);
signal sdr_a_bus	: std_logic_vector(24 downto 0);
signal sdr_di_bus	: std_logic_vector(7 downto 0);
signal sdr_do_bus	: std_logic_vector(7 downto 0);
signal rom_do_bus	: std_logic_vector(7 downto 0);
signal sdr_wr		: std_logic;
signal sdr_rd		: std_logic;
signal sdr_rfsh		: std_logic;
-- Port
signal port_xxfe_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_1ffd_reg	: std_logic_vector(7 downto 0);
signal port_7ffd_reg	: std_logic_vector(7 downto 0);
signal port_dffd_reg	: std_logic_vector(7 downto 0);
signal port_0000_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_0001_reg	: std_logic_vector(7 downto 0) := "00000100";
-- PS/2 Keyboard
signal kb_do_bus	: std_logic_vector(4 downto 0);
signal kb_f_bus		: std_logic_vector(12 downto 1);
signal kb_joy_bus	: std_logic_vector(4 downto 0);
-- Video
signal vid_a_bus	: std_logic_vector(12 downto 0);
signal vid_di_bus	: std_logic_vector(7 downto 0);
signal vid_wr		: std_logic;
signal vid_scr		: std_logic;
signal vid_hsync	: std_logic;
signal vid_vsync	: std_logic;
signal vid_hcnt		: std_logic_vector(8 downto 0);
signal vid_int		: std_logic;
signal rgb			: std_logic_vector(5 downto 0);

signal vga_hsync	: std_logic;
signal vga_vsync	: std_logic;
signal vga_blank	: std_logic;
-- Z-Controller
signal zc_do_bus	: std_logic_vector(7 downto 0);
signal zc_rd		: std_logic;
signal zc_wr		: std_logic;
signal zc_cs_n		: std_logic;
signal zc_sclk		: std_logic;
signal zc_mosi		: std_logic;
signal zc_miso		: std_logic;
-- SPI
signal spi_si		: std_logic;
signal spi_so		: std_logic;
signal spi_clk		: std_logic;
signal spi_wr		: std_logic;
signal spi_cs_n		: std_logic;
signal spi_do_bus	: std_logic_vector(7 downto 0);
signal spi_busy		: std_logic;
-- PCF8583
signal rtc_do_bus	: std_logic_vector(7 downto 0);
signal rtc_wr		: std_logic;
-- MC146818A
signal mc146818_wr	: std_logic;
signal mc146818_a_bus	: std_logic_vector(5 downto 0);
signal mc146818_do_bus	: std_logic_vector(7 downto 0);
signal port_bff7	: std_logic;
signal port_eff7_reg	: std_logic_vector(7 downto 0);
-- TurboSound
signal ssg_sel		: std_logic;
signal ssg_cn0_bus	: std_logic_vector(7 downto 0);
signal ssg_cn0_a	: std_logic_vector(7 downto 0);
signal ssg_cn0_b	: std_logic_vector(7 downto 0);
signal ssg_cn0_c	: std_logic_vector(7 downto 0);
signal ssg_cn1_bus	: std_logic_vector(7 downto 0);
signal ssg_cn1_a	: std_logic_vector(7 downto 0);
signal ssg_cn1_b	: std_logic_vector(7 downto 0);
signal ssg_cn1_c	: std_logic_vector(7 downto 0);
signal audio_l		: std_logic_vector(11 downto 0);
signal audio_r		: std_logic_vector(11 downto 0);
signal dac_s_l		: std_logic_vector(11 downto 0);
signal dac_s_r		: std_logic_vector(11 downto 0);
signal sound		: std_logic_vector(7 downto 0);
-- Soundrive
signal covox_a		: std_logic_vector(7 downto 0);
signal covox_b		: std_logic_vector(7 downto 0);
signal covox_c		: std_logic_vector(7 downto 0);
signal covox_d		: std_logic_vector(7 downto 0);
-- beeper
signal beeper		: std_logic;
-- CLOCK
signal clk_bus		: std_logic;
signal clk_sdr		: std_logic;
signal clk7			: std_logic;
signal clk14		: std_logic;
------------------------------------
signal ena_14mhz	: std_logic;
signal ena_7mhz		: std_logic;
signal ena_3_5mhz	: std_logic;
signal ena_1_75mhz	: std_logic;
signal ena_0_4375mhz	: std_logic;
signal ena_cnt		: std_logic_vector(5 downto 0);
-- System
signal reset		: std_logic;
signal areset		: std_logic;
signal boot_reset 	: std_logic;
signal key_reset	: std_logic;
signal locked		: std_logic;
signal dos_act		: std_logic := '1';
signal cpuclk		: std_logic;
signal selector		: std_logic_vector(4 downto 0);
signal key_f		: std_logic_vector(12 downto 1);
signal key		: std_logic_vector(12 downto 1) := "000000000001"; -- F1=3.5, F2=7.0, F3=14, default to 3.5
-- divmmc
signal divmmc_do	: std_logic_vector(7 downto 0);
signal divmmc_amap	: std_logic;
signal divmmc_e3reg	: std_logic_vector(7 downto 0);	
signal divmmc_cs_n	: std_logic;
signal divmmc_sclk	: std_logic;
signal divmmc_mosi	: std_logic;
signal mux		: std_logic_vector(3 downto 0);
-- vga video
signal VideoR		: std_logic_vector(1 downto 0);
signal VideoG		: std_logic_vector(1 downto 0);
signal VideoB		: std_logic_vector(1 downto 0);
signal Hsync		: std_logic;
signal Vsync		: std_logic;
signal Sblank		: std_logic;
signal VideoR_S		: std_logic_vector(1 downto 0);
signal VideoG_S		: std_logic_vector(1 downto 0);
signal VideoB_S		: std_logic_vector(1 downto 0);
-- Loader
signal loader_host_reset : std_logic;
signal loader_ps2_clk : std_logic;
signal loader_ps2_dat : std_logic;
signal loader_uart_rxd : std_logic;
signal loader_uart_txd : std_logic;
-- Host ps/2
signal host_ps2_clk : std_logic;
signal host_ps2_dat : std_logic;
-- Host SD card
signal host_sd_clk	: std_logic;
signal host_sd_cs	: std_logic;
signal host_sd_mosi : std_logic;
signal host_sd_miso : std_logic;
-- Host memory
signal host_mem_a_bus	: std_logic_vector(24 downto 0);
signal host_mem_di_bus	: std_logic_vector(7 downto 0);
signal host_mem_wr		: std_logic;
signal host_mem_rd		: std_logic;
signal host_mem_rfsh	: std_logic;

begin

-- PLL
U0: entity work.altpll1
port map (
	areset		=> areset,
	inclk0		=> CLK_48MHZ,	--  48.0 MHz
	locked		=> locked,
	c0			=> clk_sdr, 	-- 84 MHz
	c1			=> clk_bus, 	-- 28 MHz
	c2			=> clk14, 		-- 14 MHz
	c3			=> clk7); 		-- 7 MHz
 	
-- Zilog Z80A CPU
U1: entity work.T80s
generic map (
	Mode		=> 0,	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
	T2Write		=> 1,	-- 0 => WR_n active in T3, 1 => WR_n active in T2
	IOWait		=> 1)	-- 0 => Single cycle I/O, 1 => Std I/O cycle
port map(
	RESET_n		=> cpu0_reset_n,
	CLK_n		=> cpuclk,
	WAIT_n		=> '1',
	INT_n		=> cpu0_int_n,
	NMI_n		=> cpu0_nmi_n,
	BUSRQ_n		=> '1',
	M1_n		=> cpu0_m1_n,
	MREQ_n		=> cpu0_mreq_n,
	IORQ_n		=> cpu0_iorq_n,
	RD_n		=> cpu0_rd_n,
	WR_n		=> cpu0_wr_n,
	RFSH_n		=> cpu0_rfsh_n,
	HALT_n		=> open,
	BUSAK_n		=> open,
	A			=> cpu0_a_bus,
	DI			=> cpu0_di_bus,
	DO			=> cpu0_do_bus,
	SavePC      => open,
	SaveINT     => open,
	RestorePC   => (others => '1'),
	RestoreINT  => (others => '1'),
	RestorePC_n => '1');

-- Video Spectrum/Pentagon
U2: entity work.video
port map (
	CLK			=> clk_bus,
	ENA			=> ena_7mhz & ena_14mhz,
	INTA		=> cpu0_inta_n,
	INT			=> cpu0_int_n,
	BORDER		=> port_xxfe_reg(2 downto 0),	-- border color defined by bits D0..D2 port xxFE
	BORDON		=> open, 
	ATTR		=> open, 
	A			=> vid_a_bus,
	DI			=> vid_di_bus,
	MODE		=> key_f(7) & key_f(12),		-- 0: Spectrum; 1: Pentagon
	BLANK		=> open, 
	RGB			=> rgb,
	HSYNC		=> vid_hsync,
	VSYNC		=> vid_vsync);
	
-- Video memory
U3: entity work.altram1
port map (
	clock_a		=> clk_bus,
	clock_b		=> clk_bus,
	address_a	=> vid_scr & cpu0_a_bus(12 downto 0),
	address_b	=> port_7ffd_reg(3) & vid_a_bus,
	data_a		=> cpu0_do_bus,
	data_b		=> "11111111",
	q_a			=> open,
	q_b			=> vid_di_bus,
	wren_a		=> vid_wr,
	wren_b		=> '0');

-- Keyboard / disabled temporary
U4: entity work.keyboard
port map(
	CLK			=> clk_bus,
	RESET		=> areset,
	A			=> cpu0_a_bus(15 downto 8),
	KEYB		=> kb_do_bus,
	KEYF		=> kb_f_bus,
	KEYJOY		=> kb_joy_bus,
	KEYRESET	=> key_reset,
	PS2_CLK 	=> PS2_CLK,
	PS2_DAT 	=> PS2_DAT
);
	
-- Z-Controller
U7: entity work.zcontroller
port map (
	RESET		=> reset,
	CLK			=> clk_bus,
	A			=> cpu0_a_bus(5),
	DI			=> cpu0_do_bus,
	DO			=> zc_do_bus,
	RD			=> zc_rd,
	WR			=> zc_wr,
	SDPROT		=> '0',
	CS_n		=> zc_cs_n,
	SCLK		=> zc_sclk,
	MOSI		=> zc_mosi,
	MISO		=> SD_SO);
	
-- SPI FLASH 25MHz Max SCK
U8: entity work.spi
port map (
	RESET		=> reset,
	CLK			=> clk_bus,
	SCK			=> clk14,
	A			=> cpu0_a_bus(0),
	DI			=> cpu0_do_bus,
	DO			=> spi_do_bus,
	WR			=> spi_wr,
	BUSY		=> spi_busy,
	CS_n		=> spi_cs_n,
	SCLK		=> spi_clk,
	MOSI		=> spi_si,
	MISO		=> spi_so);

-- TurboSound
U9: entity work.turbosound
port map (
	RESET		=> reset,
	CLK			=> clk_bus,
	ENA			=> ena_1_75mhz,
	A			=> cpu0_a_bus,
	DI			=> cpu0_do_bus,
	WR_n		=> cpu0_wr_n,
	IORQ_n		=> cpu0_iorq_n,
	M1_n		=> cpu0_m1_n,
	SEL			=> ssg_sel,
	CN0_DO		=> ssg_cn0_bus,
	CN0_A		=> ssg_cn0_a,
	CN0_B		=> ssg_cn0_b,
	CN0_C		=> ssg_cn0_c,
	CN1_DO		=> ssg_cn1_bus,
	CN1_A		=> ssg_cn1_a,
	CN1_B		=> ssg_cn1_b,
	CN1_C		=> ssg_cn1_c);

-- SDRAM Controller
U11: entity work.sdram
port map (
	CLK			=> clk_sdr,
	A			=> sdr_a_bus,
	DI			=> sdr_di_bus,
	DO			=> sdr_do_bus,
	WR			=> sdr_wr,
	RD			=> sdr_rd,
	RFSH		=> sdr_rfsh,
	RFSHREQ		=> open,
	IDLE		=> open,
	CK			=> SDRAM_CLK,
	RAS_n		=> SDRAM_RAS_n,
	CAS_n		=> SDRAM_CAS_n,
	WE_n		=> SDRAM_WE_n,
	DQML		=> SDRAM_DQML,
	DQMH		=> SDRAM_DQMH,
	BA			=> SDRAM_BA,
	MA			=> SDRAM_A,
	DQ			=> SDRAM_D);

-- Soundrive
U14: entity work.soundrive
port map (
	RESET		=> reset,
	CLK			=> clk_bus,
	CS			=> key_f(11),
	WR_n		=> cpu0_wr_n,
	A			=> cpu0_a_bus(7 downto 0),
	DI			=> cpu0_do_bus,
	IORQ_n		=> cpu0_iorq_n,
	DOS			=> dos_act,
	OUTA		=> covox_a,
	OUTB		=> covox_b,
	OUTC		=> covox_c,
	OUTD		=> covox_d);

-- divmmc interface
U18: entity work.divmmc
port map (
	CLK			=> clk_bus,
	EN			=> key_f(6),
	RESET		=> reset,
	ADDR		=> cpu0_a_bus,
	DI			=> cpu0_do_bus,
	DO			=> divmmc_do,
	WR_N		=> cpu0_wr_n,
	RD_N		=> cpu0_rd_n,
	IORQ_N		=> cpu0_iorq_n,
	MREQ_N		=> cpu0_mreq_n,
	M1_N		=> cpu0_m1_n,
	E3REG		=> divmmc_e3reg,
	AMAP		=> divmmc_amap,
	CS_N		=> divmmc_cs_n,
	SCLK		=> divmmc_sclk,
	MOSI		=> divmmc_mosi,
	MISO		=> SD_SO);

-- Delta-Sigma L
U19: entity work.dac
port map (
    CLK   		=> clk_sdr,
    RESET 		=> areset,
    DAC_DATA	=> dac_s_l,
    DAC_OUT   	=> DAC_OUT_L);

-- Delta-Sigma R
U20: entity work.dac
port map (
    CLK   		=> clk_sdr,
    RESET 		=> areset,
    DAC_DATA	=> dac_s_r,
    DAC_OUT   	=> DAC_OUT_R);

-- Loader
U21: entity work.loader 
generic map (
	mem_a_offset 		=> 17301504, 	-- GLUK ROM start point (0x1080000) 
	loader_filesize 	=> 81920,  		-- SPECCY.ROM filesize (bytes)
	use_osd				=> true, 		-- show OSD
	clk_frequency 		=> 840 			-- loader clk frequency * 10
)
port map (
	clk 				=> clk_sdr, 			 -- 84 MHz for loader_ctl and vga_master
	clk_low 			=> ena_3_5mhz,			 -- 3.5 MHz for mem write 
	reset 				=> areset or not locked, -- global reset

	-- physical connections to SD card
	sd_clk 				=> SD_CLK,
	sd_cs 				=> SD_CS_n,
	sd_mosi 			=> SD_SI,
	sd_miso 			=> SD_SO,

	-- physical connections to VGA out		
	vga_r(7 downto 3) 	=> VGA_R,
	vga_g(7 downto 2) 	=> VGA_G,
	vga_b(7 downto 3) 	=> VGA_B,
	vga_hs 				=> VGA_HS,
	vga_vs 				=> VGA_VS,

	-- physical connections to UART RX/TX
--	uart_rxd 			=> UART_RXD,
--	uart_txd 			=> UART_TXD,
	
--	ps2_clk 			=> PS2_CLK,
--	ps2_dat 			=> PS2_DAT,

	-- ram controller connections
	mem_di_bus 			=> sdr_di_bus,
	mem_a_bus 			=> sdr_a_bus,
	mem_wr 				=> sdr_wr,
	mem_rd 				=> sdr_rd,
	mem_rfsh 			=> sdr_rfsh,

	-- host to loader signals
	host_sd_clk 			=> host_sd_clk,
	host_sd_cs 				=> host_sd_cs,
	host_sd_mosi 			=> host_sd_mosi,
	host_sd_miso 			=> host_sd_miso,

	host_vga_r(7 downto 6) 	=> VideoR_S,
	host_vga_g(7 downto 6) 	=> VideoG_S,
	host_vga_b(7 downto 6) 	=> VideoB_S,
	host_vga_hs 			=> HSync,
	host_vga_vs 			=> VSync,

	host_mem_di_bus 		=> host_mem_di_bus,
	host_mem_a_bus 			=> host_mem_a_bus,
	host_mem_wr 			=> host_mem_wr,
	host_mem_rd 			=> host_mem_rd,
	host_mem_rfsh 			=> host_mem_rfsh,

	-- loader output signals
	host_reset 				=> loader_host_reset
);

-- Test ROM 2k
--U22: entity work.testrom
--	port map (
--		address => cpu0_a_bus(10 downto 0),
--		clock => clk_bus,
--		q => rom_do_bus
--	);

-------------------------------------------------------------------------------
-- GLobal clock signals generation
process (clk_bus)
begin
	if clk_bus'event and clk_bus = '0' then
		ena_cnt <= ena_cnt + 1;
	end if;
end process;

-- permanent connections
SDRAM_CKE 		<= '1'; 	-- pullup
SDRAM_CS_N 		<= '0'; 	-- pulldown
BUZZER 			<= '1'; 		-- nc / todo

-- cpu clock signals
ena_14mhz 		<= ena_cnt(0);
ena_7mhz 		<= ena_cnt(1) and ena_cnt(0);
ena_3_5mhz 		<= ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
-- ssg clock signals
ena_1_75mhz 	<= ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
ena_0_4375mhz 	<= ena_cnt(5) and ena_cnt(4) and ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);

areset 			<= not KEYS(3);																-- global reset (S4 button)
reset 			<= areset or not KEYS(2) or loader_host_reset or key_reset or not locked;	-- hot reset (S3 button)

cpu0_reset_n 	<= not(reset) and not(kb_f_bus(4));						-- CPU reset (F4 kbd button)
cpu0_inta_n 	<= cpu0_iorq_n or cpu0_m1_n;							-- INTA
cpu0_nmi_n 		<= not kb_f_bus(5);										-- NMI (F5 kbd button)

-------------------------------------------------------------------------------
-- Clock dividers
cpuclk 			<= clk_bus and cpu0_ena;
cpu0_mult 		<= key_f(3) & key_f(2) & key_f(1); -- functional keys state
process (cpu0_mult, ena_3_5mhz, ena_7mhz, ena_14mhz)
begin
	case cpu0_mult is
		when "001" => cpu0_ena <= ena_3_5mhz;
		when "010" => cpu0_ena <= ena_7mhz;
		when "100" => cpu0_ena <= ena_14mhz;
		when others => cpu0_ena <= ena_3_5mhz;
	end case;
end process;

-------------------------------------------------------------------------------
-- SDRAM host signals
host_mem_di_bus 	<= cpu0_do_bus;
host_mem_a_bus 		<= ram_a_bus & cpu0_a_bus(12 downto 0);
host_mem_rfsh 		<= not cpu0_rfsh_n;
host_mem_rd 		<= not (cpu0_mreq_n or cpu0_rd_n);
host_mem_wr 		<= '1' 
						when cpu0_mreq_n = '0' and cpu0_wr_n = '0' -- Write request from CPU
						and (
							mux = "1001" 				-- ESXDOS RAM 2000-3FFF
							or mux(3 downto 2) = "11" 	-- Seg2 / Seg3 RAM 
							or mux(3 downto 2) = "01"   -- Seg2 / Seg3 RAM
							or mux(3 downto 1) = "101"  -- Seg 1 RAM
							or mux(3 downto 1) = "001"  -- Seg 1 RAM 
							) 
						else '0';

-------------------------------------------------------------------------------
-- SD host signals
host_sd_cs 		<= divmmc_cs_n when key_f(6)='1' else zc_cs_n;
host_sd_clk 	<= divmmc_sclk when key_f(6)='1' else zc_sclk;
host_sd_mosi 	<= divmmc_mosi when key_f(6)='1' else zc_mosi;

-------------------------------------------------------------------------------
-- Registers

process (areset, clk_bus, cpu0_a_bus, port_0000_reg, cpu0_mreq_n, cpu0_wr_n, cpu0_do_bus, port_0001_reg)
begin
	if areset = '1' then
		port_0000_reg <= (others => '0'); -- port #DFFD mask (by AND)
		port_0001_reg <= "00000100";
	elsif clk_bus'event and clk_bus = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(15 downto 0) = X"0000" then port_0000_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(15 downto 0) = X"0001" then port_0001_reg <= cpu0_do_bus; end if;
	end if;
end process;

process (reset, clk_bus, cpu0_a_bus, dos_act, port_1ffd_reg, port_7ffd_reg, port_dffd_reg, cpu0_mreq_n, cpu0_wr_n, cpu0_do_bus)
begin
	if reset = '1' then
		port_eff7_reg <= (others => '0');
		port_1ffd_reg <= (others => '0');
		port_7ffd_reg <= (others => '0');
		port_dffd_reg <= (others => '0');
		dos_act <= '1';
	elsif clk_bus'event and clk_bus = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 0) = X"FE" then port_xxfe_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"EFF7" then port_eff7_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"1FFD" then port_1ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"7FFD" and port_7ffd_reg(5) = '0' then port_7ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"DFFD" and port_7ffd_reg(5) = '0' then port_dffd_reg <= cpu0_do_bus; end if;
		--if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"DFF7" and port_eff7_reg(7) = '1' then mc146818_a_bus <= cpu0_do_bus(5 downto 0); end if;
		if cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 8) = X"3D" and port_7ffd_reg(4) = '1' then dos_act <= '1';
		elsif cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 14) /= "00" then dos_act <= '0'; end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Selector
mux <= ((divmmc_amap or divmmc_e3reg(7)) and key_f(6)) & cpu0_a_bus(15 downto 13);

process (mux, port_7ffd_reg, port_dffd_reg, port_0000_reg, ram_a_bus, cpu0_a_bus, dos_act, port_1ffd_reg, divmmc_e3reg, key_f)
begin
	case mux is
		when "0000" => ram_a_bus <= "100001000" & ((not(dos_act) and not(port_1ffd_reg(1))) or key_f(6)) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '0';	-- Seg0 ROM 0000-1FFF
		when "0001" => ram_a_bus <= "100001000" & ((not(dos_act) and not(port_1ffd_reg(1))) or key_f(6)) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '1';	-- Seg0 ROM 2000-3FFF
		when "1000" => ram_a_bus <= "100001001000";	-- ESXDOS ROM 0000-1FFF
		when "1001" => ram_a_bus <= "100000" & divmmc_e3reg(5 downto 0);	-- ESXDOS RAM 2000-3FFF
		when "0010"|"1010" => ram_a_bus <= "000000001010";	-- Seg1 RAM 4000-5FFF
		when "0011"|"1011" => ram_a_bus <= "000000001011";	-- Seg1 RAM 6000-7FFF
		when "0100"|"1100" => ram_a_bus <= "000000000100";	-- Seg2 RAM 8000-9FFF
		when "0101"|"1101" => ram_a_bus <= "000000000101";	-- Seg2 RAM A000-BFFF
		when "0110"|"1110" => ram_a_bus <= (port_dffd_reg and port_0000_reg) & port_7ffd_reg(2 downto 0) & '0';	-- Seg3 RAM C000-DFFF
		when "0111"|"1111" => ram_a_bus <= (port_dffd_reg and port_0000_reg) & port_7ffd_reg(2 downto 0) & '1';	-- Seg3 RAM E000-FFFF
		when others => null;
	end case;
end process;

-------------------------------------------------------------------------------
-- Flash W25Q32
--NCSO <= spi_cs_n;
--ASDO <= spi_si;
--DCLK <= spi_clk;
--spi_so <= DATA0;

-------------------------------------------------------------------------------
-- Audio
beeper <= port_xxfe_reg(4);

-- 12bit Delta-Sigma DAC
audio_l <= 	  ("0000" & beeper & "0000000") + 
			  ("0000" & ssg_cn0_a) + 
			  ("0000" & ssg_cn0_b) + 
			  ("0000" & ssg_cn1_a) + 
			  ("0000" & ssg_cn1_b) + 
			  ("0000" & covox_a) + 
			  ("0000" & covox_b);
			  
audio_r <=    ("0000" & beeper & "0000000") + 
			  ("0000" & ssg_cn0_c) + 
			  ("0000" & ssg_cn0_b) + 
			  ("0000" & ssg_cn1_c) + 
			  ("0000" & ssg_cn1_b) + 
			  ("0000" & covox_c) + 
			  ("0000" & covox_d);

-- Convert signed audio data (range 127 to -128) to simple unsigned value.
dac_s_l <= std_logic_vector(unsigned(audio_l + 2048));
dac_s_r <= std_logic_vector(unsigned(audio_r + 2048));

-------------------------------------------------------------------------------
-- Port I/O
--rtc_wr		<= '1' when (cpu0_a_bus(7 downto 5) = "100" and cpu0_a_bus(3 downto 0) = "1100" and cpu0_wr_n = '0' and cpu0_iorq_n = '0') else '0'; -- Port xx8C/xx9C[xxxxxxxx_100n1100]
--mc146818_wr 	<= '1' when (port_bff7 = '1' and cpu0_wr_n = '0') else '0';
port_bff7 	<= '1' when (cpu0_iorq_n = '0' and cpu0_a_bus = X"BFF7" and cpu0_m1_n = '1' and port_eff7_reg(7) = '1') else '0';
spi_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 1) = "0000001") else '0';
zc_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';
zc_rd 		<= '1' when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';

-------------------------------------------------------------------------------
-- Functional keys Fx

-- F1  = 3.50 MHz
-- F2  = 7.00 MHz
-- F3  = 14.0 MHz 
-- F4  = CPU RESET, 
-- F5  = NMI, 
-- F6  = divMMC, 
-- F7  = frame border on/off, 
-- F11 = soundrive, 
-- F12 = video mode 0: Spectrum; 1: Pentagon;
process (areset, clk_bus, key, kb_f_bus, key_f)
begin
	if (areset = '1') then 
		key_f <= (others => '0');
		key_f(1) <= '1';			
	elsif (clk_bus'event and clk_bus = '1') then

		key <= kb_f_bus;
		
		if (kb_f_bus(12 downto 4) /= key(12 downto 4)) then
			key_f(12 downto 4) <= key_f(12 downto 4) xor key(12 downto 4);
		end if;
		
		if (kb_f_bus(3) /= key(3)) then
			key_f(3 downto 1) <= "100";
		end if;
		if (kb_f_bus(2) /= key(2)) then
			key_f(3 downto 1) <= "010";
		end if;
		if (kb_f_bus(1) /= key(1)) then
			key_f(3 downto 1) <= "001";
		end if;

	end if;
end process;

-------------------------------------------------------------------------------
-- CPU0 data bus
process (selector, rom_do_bus, sdr_do_bus, spi_do_bus, spi_busy, rtc_do_bus, mc146818_do_bus, kb_do_bus, zc_do_bus, 
		kb_joy_bus, ssg_cn0_bus, ssg_cn1_bus, divmmc_do, port_7ffd_reg, port_dffd_reg)

begin
	case selector is
		--when "00000" => cpu0_di_bus <= rom_do_bus; -- Test ROM 2k
		when "00000" => cpu0_di_bus <= sdr_do_bus;
		when "00010" => cpu0_di_bus <= sdr_do_bus;
		when "00011" => cpu0_di_bus <= spi_do_bus;
		when "00100" => cpu0_di_bus <= spi_busy & "1111111";
		--when "00101" => cpu0_di_bus <= rtc_do_bus;
		--when "00110" => cpu0_di_bus <= mc146818_do_bus;
		when "00111" => cpu0_di_bus <= "111" & kb_do_bus;
		when "01000" => cpu0_di_bus <= zc_do_bus;
		when "01101" => cpu0_di_bus <= "000" & kb_joy_bus;
		when "01110" => cpu0_di_bus <= ssg_cn0_bus;
		when "01111" => cpu0_di_bus <= ssg_cn1_bus;
		when "10011" => cpu0_di_bus <= divmmc_do;
		when "10100" => cpu0_di_bus <= port_7ffd_reg;
		when "10101" => cpu0_di_bus <= port_dffd_reg;
		when others  => cpu0_di_bus <= (others => '1');
	end case;
end process;

selector <= 
	"00000" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 14) = "00") else -- ROM
	"00010" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0') else 									  -- SDRAM
	"00011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"02") else -- W25Q32
	"00100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"03") else -- W25P32
	"00101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 5) = "100" and cpu0_a_bus(3 downto 0) = "1100") else 	-- RTC
	"00110" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and port_bff7 = '1' and port_eff7_reg(7) = '1') else -- MC146818A
	"00111" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"FE") else 			 -- Keyboard, port xxFE
	"01000" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else -- ZC
	"01101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"1F" and dos_act = '0') else 	-- Joystick, port xx1F
	"01110" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FFFD" and ssg_sel = '0') else 	-- TurboSound
	"01111" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FFFD" and ssg_sel = '1') else
	"10011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"EB" and key_f(6) = '1') else   	-- DivMMC
    "10100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"7FFD") else						-- read port 7FFD
    "10101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"DFFD") else						-- read port DFFD
	(others => '1');

-------------------------------------------------------------------------------
-- Video
vid_wr	<= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and ((ram_a_bus = "000000001010") or (ram_a_bus = "000000001110")) else '0'; 
vid_scr	<= '1' when (ram_a_bus = "000000001110") else '0';

-----------------------------------------------------------------
-- video scan converter required to display video on VGA hardware
-----------------------------------------------------------------
-- active resolution 192x256
-- take note: the values below are relative to the CLK period not standard VGA clock period
inst_scan_conv : entity work.scan_convert
generic map (
	-- mark active area of input video
	cstart      	=>  38,  -- composite sync start
	clength     	=> 352,  -- composite sync length
	-- output video timing
	hA		=>  24,	-- h front porch
	hB		=>  32,	-- h sync
	hC		=>  40,	-- h back porch
	hD		=> 352,	-- visible video
--	vA		=>   0,	-- v front porch (not used)
	vB		=>   2,	-- v sync
	vC		=>  10,	-- v back porch
	vD		=> 284,	-- visible video
	hpad		=>   0,	-- create H black border
	vpad		=>   0	-- create V black border
)
port map (
	I_VIDEO		=> rgb,
	I_HSYNC		=> vid_hsync,
	I_VSYNC		=> vid_vsync,
	O_VIDEO(5 downto 4)	=> VideoR,
	O_VIDEO(3 downto 2)	=> VideoG,
	O_VIDEO(1 downto 0)	=> VideoB,
	O_HSYNC		=> HSync,
	O_VSYNC		=> VSync,
	O_CMPBLK_N	=> Sblank,
	CLK		=> clk7,
	CLK_x2		=> clk14);

VideoR_S <= VideoR when Sblank = '1' else "00";
VideoG_S <= VideoG when Sblank = '1' else "00";
VideoB_S <= VideoB when Sblank = '1' else "00";

	
end rtl;

