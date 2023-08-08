--
-- CPU register file
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.XLEN;

entity riscy_regfile is
    port(
        clk, rst    : in std_logic;

        -- Read port 0
        i_radr1     : in unsigned(4 downto 0);
        o_rdata1    : out std_logic_vector(XLEN-1 downto 0);

        -- Read port 1
        i_radr2     : in unsigned(4 downto 0);
        o_rdata2    : out std_logic_vector(XLEN-1 downto 0);

        -- Write port
        i_wadr      : in unsigned(4 downto 0);
        i_wena      : in std_logic;
        i_wdata     : in std_logic_vector(XLEN-1 downto 0)
    );
end entity riscy_regfile;

architecture riscy_regfile_rtl of riscy_regfile is
    type regs_type is array(0 to 32-1) of std_logic_vector(XLEN-1 downto 0);
    signal regs : regs_type;
begin

    -- Register file logic
    process(clk)
    begin
        if rising_edge(clk) then
            o_rdata1 <= regs(to_integer(i_radr1));
            o_rdata2 <= regs(to_integer(i_radr2));
            if i_wena = '1' then
                if i_wadr /= 0 then
                    regs(to_integer(i_wadr)) <= i_wdata;
                end if;
                regs(0) <= (others => '0');
            end if;
        end if;
    end process;

end architecture riscy_regfile_rtl;

