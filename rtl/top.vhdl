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
        l1cache             : boolean := false;
        l2cache             : boolean := false;

        -- Unit test hex dump filename (set to empty if not a unit test)
        hex_dump_file       : string := ""
    );
    port(
        clk                 : in std_logic;
        rst                 : in std_logic;

        -- CPU core fault and environment 
        o_core_fault        : out fault_type;
        o_ecall             : out std_logic;
        o_ecall_regs        : out regfile_vector_type;

        -- Stall injection
        i_stall             : in std_logic_vector(0 to 4)
    );

end entity riscy_top;

architecture riscy_top_rtl of riscy_top is
    -- Instruction memory signals
    signal inst_mem_ena     : std_logic;
    signal inst_mem_ready   : std_logic;
    signal inst_mem_addr    : std_logic_vector(XLEN-1 downto 0);
    signal inst_mem_data    : std_logic_vector(XLEN-1 downto 0);

    -- Data memory signals
    signal data_mem_ena     : std_logic;
    signal data_mem_we      : std_logic;
    signal data_mem_ready   : std_logic;
    signal data_mem_addr    : std_logic_vector(XLEN-1 downto 0);
    signal data_mem_data_i  : std_logic_vector(XLEN-1 downto 0);
    signal data_mem_data_o  : std_logic_vector(XLEN-1 downto 0);
begin

    --
    -- Signle RiscY CPU core
    --
    riscy_core : entity work.riscy_core
    generic map(
        hartid => 0
    )
    port map (
        i_clk=>clk,
        i_rst=>rst,

        -- Instruction memory
        o_instr_mem_ena=>inst_mem_ena,
        i_instr_mem_ready=>inst_mem_ready,
        o_instr_mem_addr=>inst_mem_addr,
        i_instr_mem_data=>inst_mem_data,

        -- Data memory
        o_data_mem_ena=>data_mem_ena,
        o_data_mem_we=>data_mem_we,
        i_data_mem_ready=>data_mem_ready,
        o_data_mem_addr=>data_mem_addr,
        o_data_mem_data=>data_mem_data_i,
        i_data_mem_data=>data_mem_data_o,

        -- CPU core fault and environment 
        o_core_fault=>o_core_fault,
        o_ecall=>o_ecall,
        o_ecall_regs=>o_ecall_regs,

        -- Stall injection
        i_stall=>i_stall
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
    inst_mem_ready <= '1';

    --
    -- Test bench data memory
    --
    data_memory : entity work.ram_generic
    generic map (
        word_length=>32,
        words=>16#1000#,
        init_file_name=>hex_dump_file
    )
    port map (
        clk=>clk,
        rw=>not(data_mem_we),
        ce=>data_mem_ena,
        address=>data_mem_addr(13 downto 2),
        data_in=>data_mem_data_i,
        data_out=>data_mem_data_o
    );
    data_mem_ready <= '1';

end architecture riscy_top_rtl;
