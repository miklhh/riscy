--
-- Top RiscY CPU module
-- Author: Mikael Henriksson (2023)
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscy_top is
    generic(
        hardid          : integer := 0;

        --

        -- Cache settings
        l1cache         : boolean := false;
        l2cache         : boolean := false;

        -- Unit test hex dump filename (set to empty if not a unit test)
        hex_dump_file   : string := ""
    );
    port(
        clk             : in std_logic;
        rst             : in std_logic;

        -- unit testing signals
        test_complete   : out std_logic;
        test_failure    : out std_logic
    );

end entity riscy_top;

architecture riscy_rtl of riscy_top is
begin

    test_complete <= '0';
    test_failure <= '0';

    --
    -- Cache settings
    --
    l1cache_gen : if l1cache generate
        assert False report "No level 1 cache supported yet" severity failure;
    end generate;
    l2cache_gen : if l2cache generate
        assert False report "No level 2 cache supported yet" severity failure;
    end generate;

    --
    -- Test bench instruction memory
    --
    instruction_memory : entity work.ram_generic
    generic map (
        word_length=>32,
        words=>16#1000#,
        init_file_name=>hex_dump_file
    )
    port map (
        clk=>clk,
        rw=>'1',  -- always read
        ce=>'1',  -- always enabled
        address=>(others => '0'),
        data_in=>(others => '0')
        --data_out=>,
    );

end architecture riscy_rtl;
