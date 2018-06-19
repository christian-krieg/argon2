-------------------------------------------------------------------------------
--
-- Argon2 testbench
--
-------------------------------------------------------------------------------
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--
-------------------------------------------------------------------------------
--
entity argon2_tb is
end argon2_tb;
--
-------------------------------------------------------------------------------
--
architecture behavior of argon2_tb is
	constant clk_period	: time := 5 ns;

	constant DEG_OF_PARALLELISM    : integer := 4;
	constant MAX_TAG_LEN_BYTE      : integer := 1024;
	constant MAX_PASSWORD_LEN_BYTE : integer := 256;
	constant MAX_SALT_LEN_BYTE     : integer := 16;
	constant MAX_ITERATION_COUNT   : integer := 1e6;
	constant MEMORY_SIZE_KIB       : integer := 65536;
	constant VERSION               : integer := 19;

	signal clk                     : std_logic;
	signal clk_200mhz              : std_logic;
	signal reset                   : std_logic;
	signal start                   : std_logic;
	signal password                : std_logic_vector(MAX_PASSWORD_LEN_BYTE * 8 - 1 downto 0);
	signal password_len_byte       : integer range 0 to MAX_PASSWORD_LEN_BYTE;
	signal iteration_count         : integer range 0 to MAX_ITERATION_COUNT := 5;
	signal tag_len_byte            : integer range 0 to MAX_TAG_LEN_BYTE := 64; 
	signal argon_type              : integer range 0 to 2 := 1;
	signal salt                    : std_logic_vector(MAX_SALT_LEN_BYTE * 8 - 1 downto 0);
	signal salt_len_byte           : integer range 0 to MAX_SALT_LEN_BYTE := 16; 
	signal tag                     : std_logic_vector(MAX_TAG_LEN_BYTE * 8 - 1 downto 0);
	signal ready                   : std_logic;
	signal current_iteration_count : integer range 0 to MAX_ITERATION_COUNT := 0;

	-- DDR2 interface
	signal ddr2_addr               : std_logic_vector(12 downto 0);
	signal ddr2_ba                 : std_logic_vector(2 downto 0);
	signal ddr2_ras_n              : std_logic;
	signal ddr2_cas_n              : std_logic;
	signal ddr2_we_n               : std_logic;
	signal ddr2_ck_p               : std_logic_vector(0 downto 0);
	signal ddr2_ck_n               : std_logic_vector(0 downto 0);
	signal ddr2_cke                : std_logic_vector(0 downto 0);
	signal ddr2_cs_n               : std_logic_vector(0 downto 0);
	signal ddr2_dm                 : std_logic_vector(1 downto 0);
	signal ddr2_odt                : std_logic_vector(0 downto 0);
	signal ddr2_dq                 : std_logic_vector(15 downto 0);
	signal ddr2_dqs_p              : std_logic_vector(1 downto 0);
	signal ddr2_dqs_n              : std_logic_vector(1 downto 0);

begin

	uut: entity work.argon2 
	generic map (
		DEG_OF_PARALLELISM,
		MAX_TAG_LEN_BYTE,
		MAX_PASSWORD_LEN_BYTE,
		MAX_SALT_LEN_BYTE,
		MAX_ITERATION_COUNT,
		MEMORY_SIZE_KIB,
		VERSION
	)
	port map (
		clk, 
		clk_200mhz,
		reset, 
		start, 
		password, 
		password_len_byte, 
		iteration_count, 
		tag_len_byte,
		argon_type,
		salt,
		salt_len_byte,
		tag,
		ready,
		current_iteration_count,
		ddr2_addr,
		ddr2_ba,
		ddr2_ras_n,
		ddr2_cas_n,
		ddr2_we_n,
		ddr2_ck_p,
		ddr2_ck_n,
		ddr2_cke,
		ddr2_cs_n,
		ddr2_dm,
		ddr2_odt,
		ddr2_dq,
		ddr2_dqs_p,
		ddr2_dqs_n
	);

	clk_process :process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	clk_200mhz_process :process
	begin
		clk_200mhz <= '0';
		wait for 2.5 ns;
		clk_200mhz <= '1';
		wait for 2.5 ns;
	end process;

	stim_proc: process
	begin
		reset <= '1';
		wait for 20 ns;
		reset <= '0';
		wait for 20 ns;
		argon_type <= 0; -- Argon2d
		iteration_count <= 3;
		tag_len_byte <= 32;
		password_len_byte <= 32;
		password(32*8-1 downto 0) <= x"0101010101010101010101010101010101010101010101010101010101010101";
		salt_len_byte <= 16;
		salt(16*8-1 downto 0) <= x"02020202020202020202020202020202";
		tag_len_byte <= 32;
		start <= '1';
		wait for 10 ns;
		start <= '0';
		wait for 400 ns;
		--assert tag(32*8-1 downto 0)=x"512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb" report "wrong tag for Argon2d test";
		
		argon_type <= 1; -- Argon2i
		start <= '1';
		wait for 10 ns;
		start <= '0';
		wait for 400 ns;
		--assert tag(32*8-1 downto 0)=x"c814d9d1dc7f37aa13f0d77f2494bda1c8de6b016dd388d29952a4c4672b6ce8" report "wrong tag for Argon2i test";
		
		argon_type <= 1; -- Argon2id
		start <= '1';
		wait for 10 ns;
		start <= '0';
		wait for 400 ns;
		--assert tag(32*8-1 downto 0)=x"0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659" report "wrong tag for Argon2id test";
		
		-- Stop simulation
		--assert false report "Successfully finished simulation" severity failure;
		--wait;
	end process;
end;
--
-------------------------------------------------------------------------------
