library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--
--------------------------------------------------------------------------------
--
entity hash_tb is
end hash_tb;
--
-------------------------------------------------------------------------------
--
architecture behav of hash_tb is

	component h is
		port(
			clk			: in  std_logic;
			rst			: in  std_logic;
			tagSize		: in  integer range 1 to 1024;
			msgIn		: in  std_logic_vector(128*8 -1 downto 0);
			inValid		: in  std_logic;
			msgLength	: in  integer range 1 to 1024; --in bytes

			hash		: out std_logic_vector( 64*8 -1 downto 0);
			outValid	: out std_logic;
			newDataRdy	: out std_logic;
			newReqRdy	: out std_logic
		);
	end component;

	for dut: h use entity work.hash;
	
	constant CLK_PERIOD : time := 10 ns;

	signal clk, rst, in_valid, out_valid, new_data_rdy, new_req_rdy : std_logic;
	signal msg_in		: std_logic_vector(128*8 -1 downto 0);
	signal hash			: std_logic_vector( 64*8 -1 downto 0);
	signal tag_size		: integer range 1 to 1024;
	signal msg_length	: integer range 1 to 1024;
--
-------------------------------------------------------------------------------
--
begin

	dut: h
	port map (
		clk			=> clk,
		rst			=> rst,
		tagSize		=> tag_size,
		inValid		=> in_valid,
		msgLength	=> msg_length,
		msgIn		=> msg_in,
		hash		=> hash,
		outValid	=> out_valid,
		newDataRdy	=> new_data_rdy,
		newReqRdy	=> new_req_rdy
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
		rst			<= '1';
		tag_size	<= 100;
		msg_in		<= (others => '0');
		in_valid	<= '0';
		msg_length	<= 1;
		wait for CLK_PERIOD/2;

		rst			<= '0';
		wait for CLK_PERIOD;
--
-------------------------------------------------------------------------------
-- Test case 1 : short message
		msg_length <= 50;
		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid	<= '0';

		wait until new_req_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;
--
-------------------------------------------------------------------------------
-- Test case 2 : short message with end of initialization
		msg_length <= 127;
		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid	<= '0';

		wait until new_req_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;
--
-------------------------------------------------------------------------------
-- Test case 3 : longer message withtout end of initialization
		msg_length <= 321;
		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_data_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;

		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_data_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;

		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_req_rdy = '1';
		wait until clk'event and clk = '1';
		wait for 10*CLK_PERIOD;
--
-------------------------------------------------------------------------------
-- Test case 4 : longer message with end of initialization
		msg_length <= 380;
		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_data_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;

		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_data_rdy = '1';
		wait until clk'event and clk = '1';
		wait for CLK_PERIOD;

		in_valid <= '1';

		wait for CLK_PERIOD;
		in_valid <= '0';

		wait until new_req_rdy = '1';
		wait until clk'event and clk = '1';


		assert false report "Simulation Finished" severity failure;
	end process;

end behav;
