----------------------------------------------------
--    Simulated Nexys4DDR SRAM to DDR component   --
--                                                --
-- Originally by DOULOS, adapted by Warren Toomey --
-- with ideas from Hamster and Erkay Savas        --
----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram2ddrxadc is
   port (
      -- Common
      clk_200MHz_i         : in    std_logic; 			  -- 200 MHz system clock
      rst_i                : in    std_logic; 			  -- not implemented!
      device_temp_i        : in    std_logic_vector(11 downto 0); -- not implemented!
      
      -- RAM interface
      ram_a                : in    std_logic_vector(26 downto 0);
      ram_dq_i             : in    std_logic_vector(15 downto 0);
      ram_dq_o             : out   std_logic_vector(15 downto 0);
      ram_cen              : in    std_logic;
      ram_oen              : in    std_logic;
      ram_wen              : in    std_logic;
      ram_ub               : in    std_logic;
      ram_lb               : in    std_logic;
      
      -- DDR2 interface.
      -- None of the signals below are implemented in this simulated component!
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
end ram2ddrxadc;

architecture behaviour of ram2ddrxadc is

   -- Timing constants
   constant tRC : time := 210 ns;
   constant tWR : time := 260 ns;

  -- The array of memory in this SRAM device
  type sram_type is array (0 to 27) of std_logic_vector(15 downto 0);
  signal sram : sram_type;

  -- Time delayed data output
  signal data_out: std_logic_vector(15 downto 0);

begin

  process(clk_200MHz_i) is begin
    if (rising_edge(clk_200MHz_i)) then

      -- Read operation. Delay the output by time tRC to ensure that
      -- the user keeps the inputs asserted until then.
      if (ram_cen = '0' and ram_oen = '0' and ram_wen = '1') then
	  data_out <= transport sram(to_integer(unsigned(ram_a))) after tRC;
      end if;

      -- Write operation. Delay the data store by time tWR to ensure that
      -- the user keeps the inputs asserted until then. Only store upper
      -- or lower byte when ram_ub/ram_lb are low
      if (ram_cen = '0' and ram_oen = '1' and ram_wen = '0') then
        if (ram_ub = '0') then
          sram(to_integer(unsigned(ram_a)))(15 downto 8) <= transport
                        ram_dq_i(15 downto 8) after tWR;
        end if;
        if (ram_lb = '0') then
          sram(to_integer(unsigned(ram_a)))(7 downto 0) <= transport
                        ram_dq_i(7 downto 0) after tWR;
        end if;
      end if;
    end if;
  end process;

  -- Enable upper/lower byte output when ram_ub/ram_lb are low
  ram_dq_o(15 downto 8) <= data_out(15 downto 8)
      when (ram_cen = '0' and ram_oen = '0' and ram_ub = '0' and ram_wen = '1') else (others=>'Z');
  ram_dq_o(7 downto 0) <= data_out(7 downto 0)
      when (ram_cen = '0' and ram_oen = '0' and ram_lb = '0' and ram_wen = '1') else (others=>'Z');

end architecture;
