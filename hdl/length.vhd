--------------------------------------------------------------------------------
-- Block to compute the length of a byte string.
--
-- The following assumptions are made about the encoding :
--			Each character is encoded on 1 byte
--			The NULL character is coded with the value 0x00.
--
-- The string is transmitted chunk by chunk, so that the interface size can be
-- fixed. The dataNew flag indicates that the current chunk at the dataIn port
-- has not yet been processed. The dataEnd flag indicates that the current chunk
-- is the last one to process.
--
-- The pending flag should be set to zero once the length has been measured. It
-- acts as an active low reset. This flag must be set to zero between every
-- length calculation.
-- There is no reset port, since it would be redundant with the pending flag.
--
-- The tooLong flag is set when the maximum measurable length MAX_LENGTH is
-- exceeded (counter overflow).
--------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--
--------------------------------------------------------------------------------
--
entity length is

	generic(
		CHUNK_SIZE	: integer := 16; --in Bytes
		MAX_LENGTH	: integer := 1024 --in Bytes
	);

	port(
		clk		: in  std_logic;
		dataIn	: in  std_logic_vector( CHUNK_SIZE*8 -1 downto 0 );
		dataNew	: in  std_logic;
		dataEnd	: in  std_logic;
		pending	: in  std_logic;

		length	: out integer range 0 to MAX_LENGTH;
		finish	: out std_logic;
		tooLong : out std_logic
	);

end length;
--
--------------------------------------------------------------------------------
--
architecture behav of length is

	signal byte_count : integer range 0 to MAX_LENGTH := 0;

begin

	length <= byte_count;

	process (clk, pending)
	begin

		if pending = '0' then
			byte_count	<= 0;
			finish		<= '0';
			tooLong		<= '0';

		elsif rising_edge(clk) then

			if dataNew = '1' then
				for k in CHUNK_SIZE downto 1 loop

					if dataIn(8*k -1 downto 8*(k-1)) = "00000000" then
						-- NULL character detected
						finish	<= '1';
					elsif byte_count + (CHUNK_SIZE -k +1) >= MAX_LENGTH +1 then
						finish	<= '1';
						tooLong	<= '1';
					else
						byte_count <= byte_count + (CHUNK_SIZE -k +1);
					end if;

				end loop;
			end if;

			if dataEnd = '1' then finish <= '1'; end if;

		end if;

	end process;

end behav;				
