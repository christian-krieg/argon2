--------------------------------------------------------------------------------
-- Block to convert an integer into an 8 byte string (LE32 function for Argon2)
--------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--
--------------------------------------------------------------------------------
--
entity le32 is

	port(
		input : in integer;
		output: out std_logic_vector(8*8 -1 downto 0)
	);

end le32;
--
--------------------------------------------------------------------------------
--
architecture behav of le32 is

	signal int_vector : std_logic_vector(31 downto 0);

begin

	int_vector <= std_logic_vector( to_unsigned (input, int_vector'length) );

	process(int_vector)
	begin
		for k in 8 downto 1 loop
			if k mod 2 = 0 then
				output(k*8 -1 downto (k-1)*8)
									 <= int_vector( (10-k)*4 -1 downto (9-k)*4)
									  & int_vector( (10-k)*4 -1 downto (9-k)*4);
			else
				output(k*8 -1 downto (k-1)*8)
									 <= int_vector( (8-k)*4 -1 downto (7-k)*4)
									  & int_vector( (8-k)*4 -1 downto (7-k)*4);
			end if;
		end loop;
	end process;

end behav;
