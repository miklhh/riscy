--
-- Top Riscy RISC-V CPU module
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_top is
    generic(

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
        test_failure    : out std_logic;
        core_fault      : out fault_type
    );

end entity riscy_top;

architecture riscy_top_rtl of riscy_top is
    -- Instruction memory signal
    signal inst_mem_ena     : std_logic;
    signal inst_mem_addr    : std_logic_vector(XLEN-1 downto 0);
    signal inst_mem_data    : std_logic_vector(XLEN-1 downto 0);
begin

    test_complete <= '0';
    test_failure <= '0';

    --
    -- Signle RiscY CPU core
    --
    riscy_core : entity work.riscy_core
    generic map(
        hartid => 0
    )
    port map (
        clk=>clk,
        rst =>rst,
        o_instr_mem_ena=>inst_mem_ena,
        o_instr_mem_addr=>inst_mem_addr,
        i_instr_mem_data=>inst_mem_data,
        o_fault=>core_fault
    );

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
        ce=>inst_mem_ena,
        address=>inst_mem_addr(13 downto 2),
        data_in=>(others => '0'),
        data_out=>inst_mem_data
    );

end architecture riscy_top_rtl;
