--
-- CPU register file
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_regfile is
    port(
        i_clk, i_rst : in std_logic;

        -- Read port 1 (RS1)
        i_radr1     : in unsigned(4 downto 0);
        o_rdata1    : out std_logic_vector(XLEN-1 downto 0);

        -- Read port 2 (RS2)
        i_radr2     : in unsigned(4 downto 0);
        o_rdata2    : out std_logic_vector(XLEN-1 downto 0);

        -- Write port
        i_wadr      : in unsigned(4 downto 0);
        i_wena      : in std_logic;
        i_wdata     : in std_logic_vector(XLEN-1 downto 0);

        -- (Optional) all regsiters read port
        o_regs      : out regfile_vector_type
    );
end entity riscy_regfile;

architecture riscy_regfile_rtl of riscy_regfile is
    signal regs_soft        : regfile_vector_type;
    signal regs             : regfile_vector_type;
    signal rdata1, rdata2   : std_logic_vector(XLEN-1 downto 0);
begin

    -- Register file logic
    process(i_clk)
    begin
        if rising_edge(i_clk) then

            -- Read port 1
            if i_wena = '1' and i_radr1 > 0 and i_radr1 = i_wadr then
                -- Read-after-write
                rdata1 <= i_wdata;
            else
                -- Normal read
                rdata1 <= regs(to_integer(i_radr1));
            end if;

            -- Read port 2
            if i_wena = '1' and i_radr2 > 0 and i_radr2 = i_wadr then
                -- Read-after-write
                rdata2 <= i_wdata;
            else
                -- Normal read
                rdata2 <= regs(to_integer(i_radr2));
            end if;

            -- Write port (soft reg file)
            if i_wena = '1' then
                if i_wadr > 0 then
                    regs_soft(to_integer(i_wadr)) <= i_wdata;
                end if;
            end if;

        end if;
    end process;

    -- Zero register always zero
    regs(1 to 31) <= regs_soft(1 to 31);
    regs(0) <= (others => '0');

    -- Assign outputs
    o_rdata1 <= rdata1;
    o_rdata2 <= rdata2;

    -- (Optional) all registers read port)
    o_regs <= regs;

end architecture riscy_regfile_rtl;

