--------------------------------------------------------------------------------
--
-- AUTHOR: Constantin Schieber <e1228774@student.tuwien.ac.at> 
-- AUTHOR: Petar Kosic <PETARMAIL> 
--
-- Package for the compress function from
-- https://tools.ietf.org/pdf/draft-irtf-cfrg-argon2-03.pdf
-- Section 3.6 
-- To be more precise, this is the round function, used by the permutation function
--------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
--
--------------------------------------------------------------------------------
--
package compress_pkg is

	-- Used for the mod 64 Operation
	constant long_bit : unsigned(63 downto 0)
	:= "1000000000000000000000000000000000000000000000000000000000000000";	
	
	-- Custom Data Type that represents an std_logic_array of 64 Bit aka 8 Byte
	type blockR is array (integer range <>) of std_logic_vector(63 downto 0);	


	-- Function that takes 64 bit and returns 32 bit std_logic_vector 
	function trunc (constant a : unsigned(63 downto 0)) return unsigned;
	
	-- Round Function of Section 3.6 in the irtf draft, used by f_PERMUTATE
	-- Uses 32 Bytes
	function f_GB (constant v_in0 : std_logic_vector(63 downto 0);
		constant v_in1 : std_logic_vector(63 downto 0);
		constant v_in2 : std_logic_vector(63 downto 0);
		constant v_in3 : std_logic_vector(63 downto 0))
	return blockR;
	
	-- Permutation Function of Section 3.6 in the irtf draft
	-- function f_PERMUTATE (constant S : std_logic_vector(128*8-1 downto 0)) 
	-- return blockR;

    -- Permutation Function of Section 3.6 in the irtf draft
	function f_PERMUTATE (constant S : std_logic_vector(128*8-1 downto 0)) 
	return blockR;

	component compress is

		port(
			i_S	: in std_logic_vector(128*8-1 downto 0);
			o_S	: out std_logic_vector(128*8-1 downto 0)
		);

	end component compress;

end compress_pkg;

package body compress_pkg is
	--
	-- @brief Truncates a 64 bit vector to 32 bit and returns it 
	-- 
	function trunc (constant a : unsigned(63 downto 0)) return unsigned is
	begin
		return a(31 downto 0);
	end;

	--
	-- @brief Calculates GB as per section 3.6
	--         Takes 32 Bytes as input
	-- @return 8 Byte Matrix Element v_x
	function f_GB (
		constant v_in0 : std_logic_vector(63 downto 0);
		constant v_in1 : std_logic_vector(63 downto 0);
		constant v_in2 : std_logic_vector(63 downto 0);
		constant v_in3 : std_logic_vector(63 downto 0))
	return blockR is
		--help variables for the permutation process
		variable a : unsigned(64-1 downto 0);
		variable b : unsigned(64-1 downto 0);
		variable c : unsigned(64-1 downto 0);
		variable d : unsigned(64-1 downto 0);
		variable t : unsigned(64-1 downto 0);
		variable v_out : blockR(0 to 3);
	begin
		a  := unsigned(v_in0);
		b  := unsigned(v_in1);
		c  := unsigned(v_in2);
		d  := unsigned(v_in3);

		a := (a + b + 2 * (trunc(a) * trunc(b))) mod long_bit;
		d := rotate_right((d xor a), 32);
		c := (c + d + 2 * (trunc(c) * trunc(d))) mod long_bit;
		b := rotate_right((b xor c), 24);

		a := (a + b + 2 * (trunc(a) * trunc(b))) mod long_bit;
		d := rotate_right((d xor a), 16);
		c := (c + d + 2 * (trunc(c) * trunc(d))) mod long_bit;
		b := rotate_right((b xor c), 63);

		v_out(0) := std_logic_vector(a);
		v_out(1) := std_logic_vector(b);
		v_out(2) := std_logic_vector(c);
		v_out(3) := std_logic_vector(d);
		
		return v_out;
	end;


	--
	-- @brief Calculates Permutation as per section 3.6
	-- @param S 128 Byte Vector that represents a 4x4 Array
	-- 
	function f_PERMUTATE (
		constant S : std_logic_vector(128*8-1 downto 0))
	return blockR is
		--help variables for the permutation process
		variable v_tmp  : blockR(0 to 3);
		variable v_res : blockR(0 to 15); 
		variable offs : integer range 0 to 16;
	begin
		
		--report "***Starting Calculations***";		

		--Split the input vector into a block format
		for i in 0 to 15 loop
			v_res(15-i) := S((i+1)*64-1 downto i*64);
		end loop;
		

		-- Execute the specified permutation sequence 
		for i in 0 to 3 loop
			v_tmp := f_GB(v_res(0+i), v_res(4+i), v_res(8+i), v_res(12+i));
			v_res(0+i) 		:= v_tmp(0); 
			v_res(4+i) 		:= v_tmp(1);
			v_res(8+i) 		:= v_tmp(2);
			v_res(12+i) 	:= v_tmp(3);
		end loop;

		v_tmp := f_GB(v_res(0), v_res(5), v_res(10), v_res(15));
		v_res(0) 	:= v_tmp(0); 
		v_res(5) 	:= v_tmp(1);
		v_res(10) 	:= v_tmp(2);
		v_res(15) 	:= v_tmp(3);

		v_tmp := f_GB(v_res(1), v_res(6), v_res(11), v_res(12));
		v_res(1) 	:= v_tmp(0); 
		v_res(6) 	:= v_tmp(1);
		v_res(11) 	:= v_tmp(2);
		v_res(12) 	:= v_tmp(3);

		v_tmp := f_GB(v_res(2), v_res(7), v_res(8), v_res(13));
		v_res(2) 	:= v_tmp(0); 
		v_res(7) 	:= v_tmp(1);
		v_res(8) 	:= v_tmp(2);
		v_res(13) 	:= v_tmp(3);

		v_tmp := f_GB(v_res(3), v_res(4), v_res(9), v_res(14));
		v_res(3) 	:= v_tmp(0); 
		v_res(4) 	:= v_tmp(1);
		v_res(9) 	:= v_tmp(2);
		v_res(14) 	:= v_tmp(3);

		return v_res;
	end;
end compress_pkg;
