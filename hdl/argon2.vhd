library ieee;
use ieee.std_logic_1164.all;
--
-------------------------------------------------------------------------------
--
entity Argon2 is
    generic (
        DEG_OF_PARALLELISM    : integer := 4;
        MAX_TAG_LEN_BYTE      : integer := 1024;
        MAX_PASSWORD_LEN_BYTE : integer := 256;
        MAX_SALT_LEN_BYTE     : integer := 16;
        MAX_ITERATION_COUNT   : integer := 1e6;
        MEMORY_SIZE_KIB       : integer := 65536;
        VERSION               : integer := 19
      );
    port (
		clk        : in std_logic;
        clk_200mhz : in std_logic;
        reset      : in std_logic;
        start      : in std_logic;

        password                : in std_logic_vector(MAX_PASSWORD_LEN_BYTE * 8 - 1 downto 0);
        password_len_byte       : in integer range 0 to MAX_PASSWORD_LEN_BYTE;
        iteration_count         : in integer range 0 to MAX_ITERATION_COUNT := 10;
        tag_len_byte            : in integer range 1 to MAX_TAG_LEN_BYTE := 64;
        argon_type              : in integer range 0 to 2 := 1; -- 0: Argon2d, 1: Argon2i, 2: Argon2id
        salt                    : in std_logic_vector(MAX_SALT_LEN_BYTE * 8 - 1 downto 0);
        salt_len_byte           : in integer range 0 to MAX_SALT_LEN_BYTE := 16;
        tag                     : out std_logic_vector(MAX_TAG_LEN_BYTE * 8 - 1 downto 0);
        ready                   : out std_logic;
        current_iteration_count : out integer range 0 to MAX_ITERATION_COUNT := 0;

        -- DDR2 interface
        ddr2_addr            : out   std_logic_vector(12 downto 0);
        ddr2_ba              : out   std_logic_vector(2 downto 0);
        ddr2_ras_n           : out   std_logic;
        ddr2_cas_n           : out   std_logic;
        ddr2_we_n            : out   std_logic;
        ddr2_ck_p            : out   std_logic_vector(0 downto 0);
        ddr2_ck_n            : out   std_logic_vector(0 downto 0);
        ddr2_cke             : out   std_logic_vector(0 downto 0);
        ddr2_cs_n            : out   std_logic_vector(0 downto 0);
        ddr2_dm              : out   std_logic_vector(1 downto 0);
        ddr2_odt             : out   std_logic_vector(0 downto 0);
        ddr2_dq              : inout std_logic_vector(15 downto 0);
        ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
        ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
	);
end Argon2;
--
-------------------------------------------------------------------------------
--
architecture behavioral of Argon2 is
--
-------------------------------------------------------------------------------
--  Signals
-------------------------------------------------------------------------------
--
    signal s_ready      : std_logic := '0';
    signal s_ready_next : std_logic := '0';

    -- input buffer
    signal s_password_buf          : std_logic_vector(MAX_PASSWORD_LEN_BYTE * 8 - 1 downto 0);
    signal s_password_len_byte_buf : integer range 0 to MAX_PASSWORD_LEN_BYTE;
    signal s_iteration_count_buf   : integer range 0 to MAX_ITERATION_COUNT 
                                        := 10;
    signal s_tag_len_byte_buf      : integer range 0 to MAX_TAG_LEN_BYTE 
                                        := 64;
    signal s_argon_type_buf        : integer range 0 to 2 := 1;
    signal s_salt_buf              : std_logic_vector(MAX_SALT_LEN_BYTE * 8 - 1 downto 0);
    signal s_salt_len_byte_buf     : integer range 0 to MAX_SALT_LEN_BYTE 
                                        := 16;

    type state_t is (
		STATE_IDLE,
        STATE_INIT,
		STATE_ROW0,
        STATE_ROW1,
        STATE_COMPRESS,
        STATE_FINAL_BLOCK,
        STATE_OUTPUT_TAG
	);

    signal state      : state_t := STATE_IDLE;
    signal state_next : state_t := STATE_IDLE;

    signal h_0      : std_logic_vector(64*8-1 downto 0);
    signal h_0_next : std_logic_vector(64*8-1 downto 0);

    -- memory
    signal s_mem_address  : std_logic_vector(26 downto 0);
    signal s_mem_data_in  : std_logic_vector(15 downto 0);
    signal s_mem_r_w      : std_logic; -- '1': write, '0': read
    signal s_mem_ready    : std_logic; -- '1': ready, '0': busy
    signal s_mem_data_out : std_logic_vector(15 downto 0);

    -- HASH function
    signal s_hash_start                 : std_logic  := '0';
    signal s_hash_start_next            : std_logic  := '0';
    signal s_hash_message               : std_logic_vector(1024*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_message_next          : std_logic_vector(1024*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_message_chunk         : std_logic_vector(128*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_message_chunk_next    : std_logic_vector(128*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_message_len_byte      : integer    := 0;
    signal s_hash_message_len_byte_next : integer    := 0;
    signal s_hash_out                   : std_logic_vector(64*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_out_next              : std_logic_vector(64*8-1 downto 0) 
                                                     := (others => '0');
    signal s_hash_valid                 : std_logic  := '0';
    signal s_hash_data_ready            : std_logic  := '0';
    signal s_hash_req_ready             : std_logic  := '0';
    signal s_hash_chunk_count           : integer    := 0;
    signal s_hash_chunk_count_next      : integer    := 0;
    signal s_hash_len_byte              : integer range 1 to 1024 := 64;
    signal s_hash_len_byte_next         : integer range 1 to 1024 := 64;

    -- le32
    type t_le32_in  is array (7 downto 0) of integer;
    type t_le32_out is array (7 downto 0) of std_logic_vector(8*8-1 downto 0);
    
    signal s_le32_in  : t_le32_in;
    signal s_le32_out : t_le32_out;

    signal s_le32_deg_of_parallelism    : std_logic_vector(8*8-1 downto 0);
    signal s_le32_tag_len_byte_buf      : std_logic_vector(8*8-1 downto 0);
    signal s_le32_memory_size_kib       : std_logic_vector(8*8-1 downto 0);
    signal s_le32_iteration_count_buf   : std_logic_vector(8*8-1 downto 0);
    signal s_le32_version               : std_logic_vector(8*8-1 downto 0);
    signal s_le32_argon_type_buf        : std_logic_vector(8*8-1 downto 0);
    signal s_le32_password_len_byte_buf : std_logic_vector(8*8-1 downto 0);
    signal s_le32_salt_len_byte_buf     : std_logic_vector(8*8-1 downto 0);
    
--
-------------------------------------------------------------------------------
--  Component declarations
-------------------------------------------------------------------------------
--
    component memory is
    	generic(
            ENABLE_16_BIT					: integer range 0 to 1; -- Default: 0 = disabled, 1 = enabled
            -- Size of FIFO buffers
            FIFO_DEPTH_WRITE				: integer := 8; -- Default: 8
            FIFO_DEPTH_READ  				: integer := 8  -- Default: 8	
	    );
        port (
            clk_200MHz : in  std_logic; -- 200 MHz system clock => 5 ns period time
            rst        : in  std_logic; -- active high system reset
            address    : in  std_logic_vector(26 downto 0); -- address space
            data_in    : in  std_logic_vector((8 * (1 + ENABLE_16_BIT) - 1) downto 0); -- data byte input
            r_w		   : in  std_logic; -- Read or Write flag: '1' ... write, '0' ... read
            mem_ready  : out std_logic; -- allocated memory ready or busy flag: '1' ... ready, '0' ... busy
            data_out   : out std_logic_vector((8 * (1 + ENABLE_16_BIT) - 1) downto 0); -- data byte output
            -- DDR2 interface
            ddr2_addr            : out   std_logic_vector(12 downto 0);
            ddr2_ba              : out   std_logic_vector(2 downto 0);
            ddr2_ras_n           : out   std_logic;
            ddr2_cas_n           : out   std_logic;
            ddr2_we_n            : out   std_logic;
            ddr2_ck_p            : out   std_logic_vector(0 downto 0);
            ddr2_ck_n            : out   std_logic_vector(0 downto 0);
            ddr2_cke             : out   std_logic_vector(0 downto 0);
            ddr2_cs_n            : out   std_logic_vector(0 downto 0);
            ddr2_dm              : out   std_logic_vector(1 downto 0);
            ddr2_odt             : out   std_logic_vector(0 downto 0);
            ddr2_dq              : inout std_logic_vector(15 downto 0);
            ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
            ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
        );
    end component;

    component hash is
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
    end component hash;

    component le32 is
        port(
            input : in integer;
            output: out std_logic_vector(8*8-1 downto 0)
        );
	end component le32;

    component floor
    	port(
            input	: in real;
            output  : out integer
	    );
    end component floor;

begin
--
-------------------------------------------------------------------------------
-- Component Instantiation
-------------------------------------------------------------------------------
--
    -- Memory
    memory_inst: memory
        generic map (
            1, 8, 8
        )
        port map (
            clk_200MHz      => clk_200mhz,     -- here: 200MHz_signal required
            rst             => reset,
            address         => s_mem_address,
            data_in         => s_mem_data_in,
            r_w             => s_mem_r_w,
            mem_ready       => s_mem_ready,
            data_out        => s_mem_data_out,
            -- DDR2 interface
            ddr2_addr       => ddr2_addr,
            ddr2_ba         => ddr2_ba,
            ddr2_ras_n      => ddr2_ras_n,
            ddr2_cas_n      => ddr2_cas_n,
            ddr2_we_n       => ddr2_we_n,
            ddr2_ck_p       => ddr2_ck_p,
            ddr2_ck_n       => ddr2_ck_n,
            ddr2_cke        => ddr2_cke,
            ddr2_cs_n       => ddr2_cs_n,
            ddr2_dm         => ddr2_dm,
            ddr2_odt        => ddr2_odt,
            ddr2_dq         => ddr2_dq,
            ddr2_dqs_p      => ddr2_dqs_p,
            ddr2_dqs_n      => ddr2_dqs_n
        );

    hash_inst: hash
        port map(
            clk			=> clk,
            rst			=> reset,
            tagSize		=> s_hash_len_byte,
            msgIn		=> s_hash_message_chunk,
            inValid		=> s_hash_start,
            msgLength   => s_hash_message_len_byte,

            hash		=> s_hash_out,
            outValid	=> s_hash_valid,
            newDataRdy	=> s_hash_data_ready,
            newReqRdy	=> s_hash_req_ready
        );

    le32_gen : for i in 0 to 7 generate
        le32_inst: le32
            port map(
                input  => s_le32_in(i),
                output => s_le32_out(i)
            );
    end generate le32_gen;

    s_le32_in(0) <= DEG_OF_PARALLELISM;
    s_le32_in(1) <= s_tag_len_byte_buf;
    s_le32_in(2) <= MEMORY_SIZE_KIB;
    s_le32_in(3) <= s_iteration_count_buf;
    s_le32_in(4) <= VERSION;
    s_le32_in(5) <= s_argon_type_buf;
    s_le32_in(6) <= s_password_len_byte_buf;
    s_le32_in(7) <= s_salt_len_byte_buf;

    s_le32_deg_of_parallelism    <= s_le32_out(0);
    s_le32_tag_len_byte_buf      <= s_le32_out(1);
    s_le32_memory_size_kib       <= s_le32_out(2);
    s_le32_iteration_count_buf   <= s_le32_out(3);
    s_le32_version               <= s_le32_out(4);
    s_le32_argon_type_buf        <= s_le32_out(5);
    s_le32_password_len_byte_buf <= s_le32_out(6);
    s_le32_salt_len_byte_buf     <= s_le32_out(7);

--
-------------------------------------------------------------------------------
--
-- main state machine
--
    sync : process (clk, reset)
    begin
        if(reset = '1') then
            state                   <= STATE_IDLE;
            s_ready                 <= '0';
            s_hash_start            <= '0';
            s_hash_chunk_count      <= 0;
            s_hash_len_byte         <= 64;
            s_hash_message          <= (others => '0');
            s_hash_message_len_byte <= 0;
            s_hash_chunk_count      <= 0;
            s_hash_message_chunk    <= (others => '0');
            h_0                     <= (others => '0');

        elsif(CLK'event and CLK='1') then   
            state                   <= state_next;
            s_ready                 <= s_ready_next;
            s_hash_start            <= s_hash_start_next;
            s_hash_chunk_count      <= s_hash_chunk_count_next;
            s_hash_len_byte         <= s_hash_len_byte_next;
            s_hash_message          <= s_hash_message_next;
            s_hash_message_len_byte <= s_hash_message_len_byte_next;
            s_hash_chunk_count      <= s_hash_chunk_count_next;
            s_hash_message_chunk    <= s_hash_message_chunk_next;
            h_0                     <= h_0_next;
        end if;
    end process sync;

    state_machine : process (clk)
    begin
        state_next                   <= state;
        s_ready_next                 <= s_ready;
        s_hash_start_next            <= s_hash_start;
        s_hash_chunk_count_next      <= s_hash_chunk_count;
        s_hash_len_byte_next         <= s_hash_len_byte;
        s_hash_message_next          <= s_hash_message;
        s_hash_message_len_byte_next <= s_hash_message_len_byte;
        s_hash_chunk_count_next      <= s_hash_chunk_count;
        s_hash_message_chunk_next    <= s_hash_message_chunk;
        h_0_next                     <= h_0;

        case state is
            when STATE_IDLE => 
                s_ready_next <= '1';
                
                if(start = '1' and s_hash_req_ready = '1') then
                    -- buffer inputs
                    s_password_buf          <= password;
                    s_password_len_byte_buf <= password_len_byte;
                    s_iteration_count_buf   <= iteration_count;
                    s_tag_len_byte_buf      <= tag_len_byte;
                    s_argon_type_buf        <= argon_type;
                    s_salt_buf              <= salt;
                    s_salt_len_byte_buf     <= salt_len_byte;
                    
                    s_hash_message_len_byte_next <= 80 + 
                                                    s_password_len_byte_buf + 
                                                    s_salt_len_byte_buf;

                    -- hash message to calc H_0
                    s_hash_message_next((80+s_password_len_byte_buf+s_salt_len_byte_buf)*8-1 downto 0) <=  
                                            s_le32_deg_of_parallelism &
                                            s_le32_tag_len_byte_buf &
                                            s_le32_memory_size_kib &
                                            s_le32_iteration_count_buf &
                                            s_le32_version &
                                            s_le32_argon_type_buf &
                                            s_le32_password_len_byte_buf &
                                            s_password_buf(s_password_len_byte_buf*8-1 downto 0) & 
                                            s_le32_salt_len_byte_buf & 
                                            s_salt_buf(s_salt_len_byte_buf*8-1 downto 0) &
                                            x"00000000" &
                                            x"00000000";

                    s_hash_chunk_count_next      <=  (s_hash_message_len_byte-1)/128;
                    s_hash_message_chunk_next    <=  s_hash_message(128*8*((s_hash_message_len_byte-1)/128+1)-1 downto
                                                                    128*8*(s_hash_message_len_byte-1)/128);
                    
                    s_ready_next            <= '0';
                    s_hash_start_next       <= '1';
                    s_hash_chunk_count_next <=  0;
                    s_hash_len_byte_next    <=  64;
                    state_next              <= STATE_INIT;
                end if;
            when STATE_INIT => 
                s_hash_start_next <= '0';

                if(s_hash_data_ready = '1' and s_hash_chunk_count > 0) then
                    s_hash_message_chunk_next <= s_hash_message(128*8*(s_hash_chunk_count+1)-1 downto
                                                                128*8*s_hash_chunk_count);
                    s_hash_chunk_count_next   <= s_hash_chunk_count - 1;
                    s_hash_start_next         <= '1';
                elsif(s_hash_valid = '1') then
                    h_0_next   <= s_hash_out;
                    state_next <= STATE_ROW0;
                end if;

            when STATE_ROW0 =>

            when STATE_ROW1 => 

            when STATE_COMPRESS =>

            when STATE_FINAL_BLOCK =>

            when STATE_OUTPUT_TAG =>

        end case;
    end process state_machine;


--
-------------------------------------------------------------------------------
--
-- map signals to outputs
--
    ready <= s_ready;
end behavioral;