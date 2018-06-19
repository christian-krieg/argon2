-------------------------------------------------------------------------------
--
-- Memory Interface package
--
-------------------------------------------------------------------------------
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--
-------------------------------------------------------------------------------
--
package memory_pkg is

	component memory is

	-- 'ENABLE_16_BIT', 'FIFO_DEPTH_WRITE' and 'FIFO_DEPTH_READ' is the generic value of the entity.
	-- 'clk_200MHz', 'rst', 'address', 'data_in' and 'r_w' are the inputs of entity.
	-- 'mem_ready' and 'data_out' are the outputs of the entity.

	generic(
		ENABLE_16_BIT				: integer range 0 to 1 := 0; -- Default: 0 = disabled, 1 = enabled
		-- Size of FIFO buffers
		FIFO_DEPTH_WRITE			: integer := 8; -- Default: 8
		FIFO_DEPTH_READ  			: integer := 8  -- Default: 8	
	);
		
	port (
    	clk_200MHz      			: in  std_logic; -- 200 MHz system clock => 5 ns period time
		rst             			: in  std_logic; -- active high system reset
		address 	     				: in  std_logic_vector(26 downto 0); -- address space
		data_in          			: in  std_logic_vector((8 * (1 + ENABLE_16_BIT) - 1) downto 0); -- data byte input
		r_w			     			: in  std_logic; -- Read or Write flag: '1' ... write, '0' ... read
		mem_ready					: out std_logic; -- allocated memory ready or busy flag: '1' ... ready, '0' ... busy
		data_out         			: out std_logic_vector((8 * (1 + ENABLE_16_BIT) - 1) downto 0); -- data byte output
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
	
	end component memory;
	
end memory_pkg;

