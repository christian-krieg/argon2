--------------------------------------------------------------------------------
-- Block to perform the variable-length hashing for Argon2.
--
-- The input is processed by chunks of 128 bytes. If the last chunk is not full
-- (i.e. if the message length is not 0 mod 128), the bytes which are actually
-- read are the last ones (xx downto 0).
--
-- Set the inValid flag to indicate the system that it should process the
-- msgIn data. If the system is expecting a message longer than what it has
-- already received, this will be treated as the next chunk of data. If the
-- system is idle, this will trigger a new processing sequence.
--
-- The result is outputed by chunks of 64 bytes. A pulse on the outValid flag
-- indicates that the output has just been updated.
-- 
-- The newDataRdy flag indicates that the system is ready to process a new
-- chunk of data.
--
-- The newReqRdy flag indicates that the sytem is in idle state and ready for
-- a new processing sequence.
--
-- If the tag size is not a multiple of 64 bytes, the relevant data of the
-- last hash output are the last bytes (xx downto 0).
--
-------------------------------------------------------------------------------
--
-- DISCLAIMER : Though I'm confident that it will work in most cases, I do not
-- guarantee the correctness of this implementation.
--
-- First, the "sequential complexity" of this module is too high to assert its
-- correctness based on a simple testbench.
--
-- Second, the draft I based myself upon to write this code did not include
-- any test messges for this function (only for Argon2 as a whole), therefore
-- I could not check the correctness of the actual results.
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.blake2b;
use work.le32;
--
--------------------------------------------------------------------------------
--
entity hash is

	port(
		clk			: in  std_logic;
		rst			: in  std_logic;
		msgIn		: in  std_logic_vector(128*8 -1 downto 0);
		inValid		: in  std_logic;
		msgLength	: in  integer range 1 to 1024; --in bytes
		tagSize		: in  integer range 1 to 1024; --in bytes

		hash		: out std_logic_vector( 64*8 -1 downto 0);
		outValid	: out std_logic;
		newDataRdy	: out std_logic;
		newReqRdy	: out std_logic
	);

end hash;
--
--------------------------------------------------------------------------------
--
architecture behav of hash is

	-- State variables
	type type_state is (
		IDLE,
		INIT,
		INIT_END,
		B2_WAIT_INIT,
		CONT,
		CONT_END,
		OUT_WAIT
	);
	signal state: type_state := IDLE;

	signal t : integer range 1 to 1024;
	signal r : integer range 0 to 30;

	signal le32_t	: std_logic_vector(8*8 -1 downto 0);
	signal min_64_t	: integer range 1 to 64;

	--Bytes already transmitted to Blake2 in first phase
	signal in_byte_count	: integer range 1 to 1024 := 1;
	--Position of last byte in last chunk of input	
	signal last_byte_idx	: integer range 1 to  128 := 1;
	--Number of hashes performed in second phase
	signal iter_count		: integer range 1 to   31 := 1;
	--1 CC delay to avoid sending results in consecutive CC (state OUT_WAIT) 
	signal scc_delay		: std_logic := '0';


	-- Blake2b module control signals
	--inputs
	signal b2_msg_chk		: std_logic_vector(128*8 -1 downto 0);
	signal b2_new_chk		: std_logic;
	signal b2_last_chk		: std_logic;
	signal b2_msg_length	: integer range 0 to 1032;
	signal b2_hash_length	: integer range 1 to   64;
	--outputs
	signal b2_result		: std_logic_vector( 64*8 -1 downto 0);
	signal b2_rdy			: std_logic;
	signal b2_finish		: std_logic;


	-- Storage for intermediate hashes
	signal v : std_logic_vector( 32*8 -1 downto 0);


	-- internal flags
	signal new_data_rdy	: std_logic := '0';
	signal new_req_rdy	: std_logic := '0';
--
--------------------------------------------------------------------------------
--
begin

	compute_r : process (t)
	begin
		if t <= 64 then
			r <= 0;
		elsif t mod 32 = 0 then
			r <= to_integer(shift_right(to_unsigned(t, 12), 5)) -2;
		else
			r <= to_integer(shift_right(to_unsigned(t, 12), 5)) -1;
		end if;
	end process compute_r;
--
--------------------------------------------------------------------------------
--
	with state select
		new_data_rdy <= '1'		when IDLE,
						b2_rdy	when INIT,
						'0'		when others;
	newDataRdy <= new_data_rdy and (not rst);

	new_req_rdy <= '1' when state = IDLE else '0';
	newReqRdy	<= new_req_rdy and (not rst);
--
--------------------------------------------------------------------------------
--
	process (clk, rst)
	begin

		if rst = '1' then
			state		<= IDLE;

			hash		<= (others => '0');
			outValid	<= '0';

			in_byte_count	<= 1;
			last_byte_idx	<= 1;
			iter_count		<= 1;
			scc_delay		<= '0';
			v				<= (others => '0');

			b2_msg_chk		<= (others => '0');
			b2_new_chk		<= '0';
			b2_last_chk		<= '0';
			b2_msg_length	<= 0;


		elsif rising_edge(clk) then

			--default values
			b2_new_chk	<= '0';
			b2_last_chk	<= '0';
			outValid	<= '0';
--
--------------------------------------------------------------------------------
-- Initialization

			if state = IDLE and inValid = '1' then

				--- set variables ---
				hash <= (others => '0');

				t <= tagSize;
				b2_msg_length <= 8 + msgLength;

				if (msgLength mod 128) = 0 then last_byte_idx <= 128;
				else last_byte_idx <= (msgLength mod 128);
				end if;

				iter_count	<= 1;
				scc_delay	<= '0';

				v <= (others => '0');
				---------------------


				if msgLength > 128 then
					--more chunks to come
					b2_msg_chk <= msgIn;
					b2_new_chk <= '1';
					in_byte_count <= 128;
					state <= INIT;

				elsif msgLength <= 120 then
					--no more chunks to come, and room for LE32(T)
					b2_msg_chk((msgLength+8)*8 -1 downto msgLength*8) <= le32_t;
					b2_msg_chk( msgLength   *8 -1 downto           0) <=
											   msgIn( msgLength*8 -1 downto 0 );
					b2_msg_chk( 128*8 -1 downto (msgLength+8)*8 ) <=
															    (others => '0');

					b2_new_chk  <= '1';
					b2_last_chk <= '1';
					state <= B2_WAIT_INIT;

				elsif msgLength = 128 then
					--no more chunks to come but no room for LE32(T)
					b2_msg_chk <= msgIn;
					b2_new_chk <= '1';
					state <= INIT_END;

				else
					--no more chunks to come, some room but not enough
					case msgLength is
					when 127 =>
						b2_msg_chk(128*8 -1 downto 127*8) <=
													   le32_t( 1*8 -1 downto 0);
						b2_msg_chk(127*8 -1 downto     0) <=
													   msgIn(127*8 -1 downto 0);
					when 126 =>
						b2_msg_chk(128*8 -1 downto 126*8) <=
													   le32_t( 2*8 -1 downto 0);
						b2_msg_chk(126*8 -1 downto     0) <=
													   msgIn(126*8 -1 downto 0);
					when 125 =>
						b2_msg_chk(128*8 -1 downto 125*8) <=
													   le32_t( 3*8 -1 downto 0);
						b2_msg_chk(125*8 -1 downto     0) <=
													   msgIn(125*8 -1 downto 0);
					when 124 =>
						b2_msg_chk(128*8 -1 downto 124*8) <=
													   le32_t( 4*8 -1 downto 0);
						b2_msg_chk(124*8 -1 downto     0) <=
													   msgIn(124*8 -1 downto 0);
					when 123 =>
						b2_msg_chk(128*8 -1 downto 123*8) <=
													   le32_t( 5*8 -1 downto 0);
						b2_msg_chk(123*8 -1 downto     0) <=
													   msgIn(123*8 -1 downto 0);
					when 122 =>
						b2_msg_chk(128*8 -1 downto 122*8) <=
													   le32_t( 6*8 -1 downto 0);
						b2_msg_chk(122*8 -1 downto     0) <=
													   msgIn(122*8 -1 downto 0);
					when 121 =>
						b2_msg_chk(128*8 -1 downto 121*8) <=
													   le32_t( 7*8 -1 downto 0);
						b2_msg_chk(121*8 -1 downto     0) <=
													   msgIn(121*8 -1 downto 0);
					when others => NULL;
					end case;

					b2_new_chk	<= '1';
					state <= INIT_END;

				end if;
--
--------------------------------------------------------------------------------
-- Initial hashing
	
			elsif state = INIT and inValid = '1' and b2_rdy = '1' then

				if in_byte_count < b2_msg_length -8 -128 then
					--more chunks to come
					b2_msg_chk	<= msgIn;
					b2_new_chk	<= '1';
					in_byte_count <= in_byte_count + 128;

				else --last chunk of data

					if last_byte_idx <= 120 then
						--no need for additional chunk
						b2_msg_chk((last_byte_idx+8)*8 -1 downto
									last_byte_idx*8) <= le32_t;

						b2_msg_chk( last_byte_idx   *8 -1 downto 0) <=
										   msgIn( last_byte_idx*8 -1 downto 0 );
						b2_msg_chk( 128*8 -1 downto (last_byte_idx+8)*8 ) <=
															    (others => '0');

						b2_new_chk  <= '1';
						b2_last_chk <= '1';
						state <= B2_WAIT_INIT;

					elsif last_byte_idx = 128 then
						--no room for LE32(T)
						b2_msg_chk <= msgIn;
						b2_new_chk <= '1';
						state <= INIT_END;
						
					else
						--some room for LE32(T) but not enough
						case last_byte_idx is
						when 127 =>
							b2_msg_chk(128*8 -1 downto 127*8) <=
													   le32_t( 1*8 -1 downto 0);
							b2_msg_chk(127*8 -1 downto     0) <=
													   msgIn(127*8 -1 downto 0);
						when 126 =>
							b2_msg_chk(128*8 -1 downto 126*8) <=
													   le32_t( 2*8 -1 downto 0);
							b2_msg_chk(126*8 -1 downto     0) <=
													   msgIn(126*8 -1 downto 0);
							when 125 =>
							b2_msg_chk(128*8 -1 downto 125*8) <=
													   le32_t( 3*8 -1 downto 0);
							b2_msg_chk(125*8 -1 downto     0) <=
													   msgIn(125*8 -1 downto 0);
						when 124 =>
							b2_msg_chk(128*8 -1 downto 124*8) <=
													   le32_t( 4*8 -1 downto 0);
							b2_msg_chk(124*8 -1 downto     0) <=
													   msgIn(124*8 -1 downto 0);
						when 123 =>
							b2_msg_chk(128*8 -1 downto 123*8) <=
													   le32_t( 5*8 -1 downto 0);
							b2_msg_chk(123*8 -1 downto     0) <=
													   msgIn(123*8 -1 downto 0);
						when 122 =>
							b2_msg_chk(128*8 -1 downto 122*8) <=
													   le32_t( 6*8 -1 downto 0);
							b2_msg_chk(122*8 -1 downto     0) <=
													   msgIn(122*8 -1 downto 0);
						when 121 =>
							b2_msg_chk(128*8 -1 downto 121*8) <=
													   le32_t( 7*8 -1 downto 0);
							b2_msg_chk(121*8 -1 downto     0) <=
													   msgIn(121*8 -1 downto 0);
						when others => NULL;
						end case;

						b2_new_chk <= '1';
						state <= INIT_END;

					end if;
				end if;
--
--------------------------------------------------------------------------------
-- End of initial hashing

			elsif state = INIT_END and b2_rdy = '1' and b2_new_chk = '0' then

				case last_byte_idx is
				when 128 =>
					b2_msg_chk(  8*8 -1 downto 0) <= le32_t(8*8 -1 downto 0*8);
					b2_msg_chk(128*8 -1 downto 8*8) <= (others => '0');
				when 127 =>
					b2_msg_chk(  7*8 -1 downto 0) <= le32_t(8*8 -1 downto 1*8);
					b2_msg_chk(128*8 -1 downto 7*8) <= (others => '0');
				when 126 =>
					b2_msg_chk(  6*8 -1 downto 0) <= le32_t(8*8 -1 downto 2*8);
					b2_msg_chk(128*8 -1 downto 6*8) <= (others => '0');
				when 125 =>
					b2_msg_chk(  5*8 -1 downto 0) <= le32_t(8*8 -1 downto 3*8);
					b2_msg_chk(128*8 -1 downto 5*8) <= (others => '0');
				when 124 =>
					b2_msg_chk(  4*8 -1 downto 0) <= le32_t(8*8 -1 downto 4*8);
					b2_msg_chk(128*8 -1 downto 4*8) <= (others => '0');
				when 123 =>
					b2_msg_chk(  3*8 -1 downto 0) <= le32_t(8*8 -1 downto 5*8);
					b2_msg_chk(128*8 -1 downto 3*8) <= (others => '0');
				when 122 =>
					b2_msg_chk(  2*8 -1 downto 0) <= le32_t(8*8 -1 downto 6*8);
					b2_msg_chk(128*8 -1 downto 2*8) <= (others => '0');
				when 121 =>
					b2_msg_chk(  1*8 -1 downto 0) <= le32_t(8*8 -1 downto 7*8);
					b2_msg_chk(128*8 -1 downto 1*8) <= (others => '0');
				when others => NULL;
				end case;

				b2_new_chk  <= '1';
				b2_last_chk <= '1';
				state <= B2_WAIT_INIT;
--
--------------------------------------------------------------------------------
-- Wait for Blake2 completion

			elsif state = B2_WAIT_INIT and b2_finish = '1' then	

				if t <= 64 then --done, output result
					hash(t*8 -1 downto 0) <= b2_result(t*8 -1 downto 0);
					outValid <= '1';
					state <= IDLE;
				else
					if r>=2 then state <= CONT;
					else state <= CONT_END;
					end if;
				end if;
--
--------------------------------------------------------------------------------
-- Continue hashing to extend the output size

			elsif state = CONT and b2_finish = '1' and b2_new_chk = '0' then

				if iter_count < r then

					b2_msg_chk(128*8 -1 downto 64*8) <= (others => '0');
					b2_msg_chk( 64*8 -1 downto    0) <= b2_result;
					b2_new_chk	<= '1';
					b2_last_chk	<= '1';
					b2_msg_length <= 64;

					iter_count <= iter_count +1;

					if iter_count mod 2 = 0 then
						 --output hash chunk
						hash <= v & b2_result(64*8 -1 downto 32*8);
						outValid <= '1';
					else
						--store hash chunk to be outputed next time
						v <= b2_result(64*8 -1 downto 32*8);
					end if;

				else
					state <= CONT_END;
				end if;
--
--------------------------------------------------------------------------------
-- Perform final hash
-- The code is the same as in the previous part but the hash length is changed
-- based solely on the state (see line 529).

			elsif state = CONT_END and b2_finish = '1' and b2_new_chk = '0' then

				if iter_count = r then

					b2_msg_chk(128*8 -1 downto 64*8) <= (others => '0');
					b2_msg_chk( 64*8 -1 downto    0) <= b2_result;
					b2_new_chk	<= '1';
					b2_last_chk	<= '1';
					b2_msg_length <= 64;

					iter_count <= iter_count +1;

					if iter_count mod 2 = 0 then
						 --output hash chunk
						hash <= v & b2_result(64*8 -1 downto 32*8);
						outValid <= '1';
					else
						--store hash chunk to be outputed next time
						v <= b2_result(64*8 -1 downto 32*8);
					end if;
--
--------------------------------------------------------------------------------
-- Last chunk of output (if there is enough room)

				else
					if iter_count mod 2 = 1 then
						--64 bytes available for output
						hash <= b2_result;
						outValid <= '1';
						state <= IDLE;

					else
						--32 bytes available for output
						if (t-32*r) <= 32 then
							--less than 32 bytes needed for output;
							hash <= (others => '0');
							hash((t-32*r+32)*8 -1 downto (t-32*r)*8) <= v;
							hash((t-32*r)   *8 -1 downto          0) <=
											  b2_result((t-32*r)*8 -1 downto 0);

							outValid <= '1';
							state <= IDLE;

						else
							--more than 32 bytes needed for output;
							hash(64*8 -1 downto 32*8) <= v;
							hash(32*8 -1 downto    0) <=
								  b2_result((t-32*r)*8 -1 downto (t-32*r-32)*8);

							v((t-32*r-32)*8 -1 downto 0) <=
										   b2_result((t-32*r-32)*8 -1 downto 0);
							
							outValid <= '1';
							state <= OUT_WAIT;

						end if;
					end if;
				end if;
--
--------------------------------------------------------------------------------
-- Final chunk of output if there was no room in the former one

			elsif state = OUT_WAIT then

				if scc_delay = '0' then --wait 1 clock cycle between two chunks
					scc_delay <= '1';

				else
					hash <= (others => '0');
					hash((t-32*r-32)*8 -1 downto 0) <= v((t-32*r-32)*8 -1 downto 0);
					outValid <= '1';
					state <= IDLE;

				end if;

			end if;
		end if;
	end process;
--
--------------------------------------------------------------------------------
-- Blake2b module instantiation

	h : entity work.blake2b
		port map(
			reset			=> rst,
			clk				=> clk,
			message			=> b2_msg_chk,
			valid_in		=> b2_new_chk,
			last_chunk		=> b2_last_chk,
			message_len		=> b2_msg_length,
			hash_len		=> b2_hash_length,
			compress_ready	=> b2_rdy,
			valid_out		=> b2_finish,
			hash			=> b2_result
		);

	with state select
		b2_hash_length <= 64 when CONT,
						  t-32*r when CONT_END,
						  min_64_t when others;

	min_64_t <= t when t<64 else 64;
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
--
end behav;				
