--------------------------------------------------------------------------------
-- Block to compute the floor of a real value.
--------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;
--
--------------------------------------------------------------------------------
--
entity floor is

	port(
		input	: in real;
		output	: out integer;
	);

end floor;
--
--------------------------------------------------------------------------------
--
architecture behav of floor is

begin

	output <= integer(floor(input));

end behav;
