--------------------------------------------------------------------------------
--
-- AUTHOR: Constantin Schieber <e1228774@student.tuwien.ac.at> 
-- AUTHOR: Petar Kosic <PETARMAIL> 
--
-- Implementation for the permutate function from
-- https://tools.ietf.org/pdf/draft-irtf-cfrg-argon2-03.pdf
-- Section 3.6 
-- To be more precise, this is the round function, used by the permutation function
--
-- SUMMARY: Input is either one row or column of 8 16-bytes registers in form of
-- a 128*8 wide std_logic_vector.
-- Output is of the same format, but with the permutation function GB applied.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.permutate_pkg.all;
--
--------------------------------------------------------------------------------
--
entity permutate is
	
	port(
		i_S	: in std_logic_vector(128*8-1 downto 0);
		o_S	: out std_logic_vector(128*8-1 downto 0)
	);

end permutate;
--
--------------------------------------------------------------------------------
--
architecture beh of permutate is

begin
	-- #TODO: Impement the Statemachine that actually uses the permutation function
	-- 			in a usefull way

	-- Only here for testbench purposes
	-- To see the actual implementation of f_PERMUTATE go to permutate_pkg.vhd
	permutation: process(i_S)
		variable v_res : blockR(0 to 15); 
	begin
		v_res := f_PERMUTATE(i_S);	
		
		-- Reassemble the returned array to a std_logic_vector
		o_S <= v_res(0) & v_res(1) & v_res(2) & v_res(3) & v_res(4) &
				 v_res(5) & v_res(6) & v_res(7) & v_res(8) & v_res(9) &
				 v_res(10) & v_res(11) & v_res(12) & v_res(13) & v_res(14) &
				 v_res(15);
	end process;
end beh;


