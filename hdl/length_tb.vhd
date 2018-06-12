library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--
--------------------------------------------------------------------------------
--
entity length_tb is
end length_tb;
--
-------------------------------------------------------------------------------
--
architecture behav of length_tb is

	component l is
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
	end component;

	for dut: l use entity work.length;
	
	constant CLK_PERIOD : time		:= 10 ns;
	constant CHUNK_SIZE	: integer	:= 4;
	constant MAX_LENGTH	: integer	:= 10;

	signal clk, data_new, data_end, pending, finish, too_long : std_logic;
	signal data_in : std_logic_vector ( CHUNK_SIZE*8 -1 downto 0);
	signal length  : integer;
--
-------------------------------------------------------------------------------
--
begin

	dut: l
	generic map (
		CHUNK_SIZE	=> CHUNK_SIZE,
		MAX_LENGTH	=> MAX_LENGTH		
	)
	port map (
		clk		=> clk,
		dataIn	=> data_in,
		dataNew	=> data_new,
		dataEnd	=> data_end,
		pending	=> pending,
		length	=> length,
		finish	=> finish,
		tooLong	=> too_long
	);

	clk_gen : process
	begin
		clk <= '0';
		wait for CLK_PERIOD/2;
		clk <= '1';
		wait for CLK_PERIOD/2;
	end process clk_gen;


	test: process
	begin
		pending		<= '0';
		data_new	<= '0';
		data_end	<= '0';
		data_in		<= "00000000" & "00000000" & "00000000" & "00000000";
		wait for CLK_PERIOD/2;
--
-------------------------------------------------------------------------------
-- 1st test case : 3 Bytes long input

		wait for CLK_PERIOD;
		data_in	<= "00000001" & "00000010" & "00000011" & "00000000";
		data_new <= '1';
		data_end <= '1';
		pending <= '1';

		wait for CLK_PERIOD;
		data_new <= '0';
		data_end <= '0';

		assert length = 3 report "1 - Wrong length" severity error;
		assert finish = '1' report "1 - finish flag" severity error;
		assert too_long = '0' report "1 - too_long flag" severity error;
--
-------------------------------------------------------------------------------
-- 2nd test case : 10 Bytes long input

		wait for CLK_PERIOD;
		pending <= '0';

		wait for CLK_PERIOD;
		data_new <= '1';
		pending <= '1';
		data_in	<= "00100001" & "01000010" & "00010011" & "00100001";

		wait for CLK_PERIOD;
		data_in	<= "00100001" & "01000010" & "00010011" & "00100001";

		wait for CLK_PERIOD;
		data_new <= '0';

		wait for 3*CLK_PERIOD;
		data_new <= '1';
		data_end <= '1';
		data_in	<= "00100001" & "01000010" & "00000000" & "00000000";

		wait for CLK_PERIOD;
		data_new <= '0';
		data_end <= '0';

		assert length = 10 report "2 - Wrong length" severity error;
		assert finish = '1' report "2 - finish flag" severity error;
--
-------------------------------------------------------------------------------
-- 3rd test case : 4 Bytes long input
		wait for CLK_PERIOD;
		pending <= '0';

		wait for CLK_PERIOD;
		pending <= '1';
		data_new <= '1';
		data_end <= '1';
		data_in	<= "00100001" & "01000010" & "00010011" & "00100001";

		wait for CLK_PERIOD;
		data_new <= '0';
		data_end <= '0';

		assert length = 4 report "3 - Wrong length" severity error;
		assert finish = '1' report "3 - finish flag" severity error;

		wait for CLK_PERIOD;
		pending <= '0';
		
		wait for CLK_PERIOD;

		assert false report "Simulation Finished" severity failure;
	end process;

end behav;
