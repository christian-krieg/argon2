-------------------------------------------------------------------------------
--
-- fifo_buffer package
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--
-------------------------------------------------------------------------------
--
package fifo_buffer_pkg is

	component fifo_buffer is

	-- 'DATA_BASE_WIDTH', 'DATA_IN_WIDTH', 'DATA_OUT_WIDTH' and 'FIFO_DEPTH' are the generic values of the entity.
	-- 'clk', 'rst', 'write', 'dataIn' and 'read' are the inputs of the entity.
	-- 'dataOut', 'empty' and 'full' are the output of the entity.

	Generic (
		constant DATA_BASE_WIDTH: integer;	--storage unit length
		constant DATA_IN_WIDTH	: integer;	--number of units stored on write
		constant DATA_OUT_WIDTH	: integer;	--number of units loaded on read
		constant FIFO_DEPTH		: integer	--number of available units
	);
	Port ( 
		clk		: in  std_logic;
		rst		: in  std_logic;
		write	: in  std_logic;
		dataIn	: in  std_logic_vector (DATA_IN_WIDTH *DATA_BASE_WIDTH -1
																	  downto 0);
		read	: in  std_logic;
		dataOut	: out std_logic_vector (DATA_OUT_WIDTH*DATA_BASE_WIDTH -1
																	  downto 0);
		empty	: out std_logic;
		full	: out std_logic
	);
	
	end component fifo_buffer;
	
end fifo_buffer_pkg;

