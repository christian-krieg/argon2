--------------------------------------------------------------------------------
-- Block to perform the variable-length hashing for Argon2.

-- Never set the inValid flag is the available flag is not already set. This
-- would result in loss of data, as there is no input buffer.
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

use work.hash;
use work.length;
use work.le32;
--
--------------------------------------------------------------------------------
--
entity argon2part1 is

	port(
		ready		: out std_logic;
	);

end argon2part1;
--
--------------------------------------------------------------------------------
--
architecture behav of argon2part1 is

	signal h0 : std_logic_vector(1024*8 -1 downto 0)

begin

	process (clk)
	begin
	
	-- step 1: H_0 Generation
		-- H_0 = H^(64)(LE32(p) || LE32(m) || LE32(t) || LE32(v) || LE32(y) || LE32(length(P)) || P || LE32(length(S)) || S || LE32(length(K)) || K || LE32(length(X)) || X )

	-- step 2: Memory allocation
		-- m' = 4 * p * floor( m / 4p)
		
	-- step 3: Lane starting blocks
		-- B[i][0] = H'(H_0 || LE32(0) || LE32(i))
		
	-- step 4: Second lane blocks
		-- B[i][1] = H'(H_0 || LE32(1) || LE32(i))
		
	-- last step sending ready signal
		
	end process;
--
--------------------------------------------------------------------------------
-- Hash module instantiation

	h : entity work.hash
		port map(
			clk			: in  std_logic;
			rst			: in  std_logic;
			tagSize		: in  integer range 1 to 1024;
			msgIn		: in  std_logic_vector( 128*8 -1 downto 0);
			inValid		: in  std_logic;
			msgLength	: in  integer range 1 to 1024; --in bytes

			hash		: out std_logic_vector(1024*8 -1 downto 0);
			outValid	: out std_logic;
			newDataRdy	: out std_logic;
			newReqRdy	: out std_logic
		);
--
--------------------------------------------------------------------------------
-- LE32 module instantiation

	le32 : entity work.le32
		port map(
			input	=> t,
			output	=> le32_t
		);

--
--------------------------------------------------------------------------------
-- length module instantiation
	length : entity work.length
		generic(
			CHUNK_SIZE	: integer; --in Bytes
			MAX_LENGTH	: integer  --in Bytes
		);
	
		port(
			clk		: in  std_logic;
			dataIn	: in  std_logic_vector( CHUNK_SIZE*8 -1 downto 0 );
			dataNew	: in  std_logic;
			dataEnd	: in  std_logic;
			pending	: in  std_logic;
	
			length	: out integer;
			finish	: out std_logic;
			tooLong : out std_logic
		);

--
--------------------------------------------------------------------------------
--
end behav;
