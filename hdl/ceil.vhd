--------------------------------------------------------------------------------
-- Block to compute the ceil of a real value.
--------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;
--
--------------------------------------------------------------------------------
--
entity ceil is

	port(
		input	: in real;
		output	: out integer;
	);

end ceil;
--
--------------------------------------------------------------------------------
--
architecture behav of ceil is

begin

	output <= integer(ceil(input));

end behav;
