-------------------------------------------------------------------------------
--
-- ram2ddrxadc package
--
-------------------------------------------------------------------------------
--
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
--
-------------------------------------------------------------------------------
--
package ram2ddrxadc_pkg is
	component ram2ddrxadc is
	   port (
		  -- Common
		  clk_200MHz_i         : in    std_logic; -- 200 MHz system clock
		  rst_i                : in    std_logic; -- active high system reset
		  device_temp_i        : in    std_logic_vector(11 downto 0);

		  -- RAM interface
		  ram_a                : in    std_logic_vector(26 downto 0);
		  ram_dq_i             : in    std_logic_vector(15 downto 0);
		  ram_dq_o             : out   std_logic_vector(15 downto 0);
		  ram_cen              : in    std_logic;
		  ram_oen              : in    std_logic;
		  ram_wen              : in    std_logic;
		  ram_ub               : in    std_logic;
		  ram_lb               : in    std_logic;

		  -- DDR2 interface
		  ddr2_addr            : out   std_logic_vector(12 downto 0);
		  ddr2_ba              : out   std_logic_vector(2 downto 0);
		  ddr2_ras_n           : out   std_logic;
		  ddr2_cas_n           : out   std_logic;
		  ddr2_we_n            : out   std_logic;
		  ddr2_ck_p            : out   std_logic_vector(0 downto 0);
		  ddr2_ck_n            : out   std_logic_vector(0 downto 0);
		  ddr2_cke             : out   std_logic_vector(0 downto 0);
		  ddr2_cs_n            : out   std_logic_vector(0 downto 0);
		  ddr2_dm              : out   std_logic_vector(1 downto 0);
		  ddr2_odt             : out   std_logic_vector(0 downto 0);
		  ddr2_dq              : inout std_logic_vector(15 downto 0);
		  ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
		  ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
	   );	
	end component ram2ddrxadc;
end ram2ddrxadc_pkg;

