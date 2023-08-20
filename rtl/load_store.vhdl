--
-- Riscy RISC-V Load-Store unit.
--
-- This unit handles load/store from/to an XLEN (32 bit) word sized cache data memorie. On unaligned
-- reads and writes, this unit creates back pressure while performing aligned reads and writes with
-- the data memory.
--
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_load_store is
    port(
        i_clk, i_rst : in std_logic;

        -- Input from execution stage
        i_skip      : in std_logic;  -- Skip this instruction
        i_inst      : in inst_type;  -- Instruction to executre
        i_addr      : in std_logic_vector(XLEN-1 downto 0);  -- Input address
        i_data      : in std_logic_vector(XLEN-1 downto 0);  -- Input data

        -- Stalling
        i_stall     : in std_logic;  -- Next stage indicating stall
        o_stall     : out std_logic; -- Stalling requested

        -- Data memory interface
        i_mem_ready : in std_logic;
        i_mem_data  : in std_logic_vector(XLEN-1 downto 0);
        o_mem_data  : out std_logic_vector(XLEN-1 downto 0);
        o_mem_addr  : out std_logic_vector(XLEN-1 downto 0);
        o_mem_ena   : out std_logic;
        o_mem_we    : out std_logic;

        -- Output to write back stage
        o_data      : out std_logic_vector(XLEN-1 downto 0);  -- Output data
        o_data_valid: out std_logic;  -- Output data is valid

        -- Fault output
        o_fault     : out fault_type
    );
end entity riscy_load_store;

architecture riscy_load_store_rtl of riscy_load_store is
    type state_type is (
        WAITING,
        LOAD_UNALIGNED,
        STORE_ALIGNED,
        STORE_UNALIGNED
    );
    signal state            : state_type;
    signal next_transaction : state_type;

    -- Analysis of next memory operation
    signal do_load          : std_logic;  -- Perform a load operation
    signal do_store         : std_logic;  -- Perform a store operation
    signal is_aligned       : std_logic;  -- Load/store instruction is memory aligned

    -- Quick (single cycle) memory operations
    signal is_quick         : std_logic;  -- Is and aligned LB, LH, LW or SW

    -- Non whole word output quick variants
    signal sign_extend      : std_logic;
    signal q_half           : std_logic_vector(XLEN-1 downto 0);
    signal q_quarter        : std_logic_vector(XLEN-1 downto 0);

    -- Delayed instruciton and target address
    signal inst_del         : inst_type;
    signal addr_del         : std_logic_vector(XLEN-1 downto 0);

    -- Stalling data preservation
    signal mem_data_saved   : std_logic_vector(XLEN-1 downto 0);
    signal mem_data_mux     : std_logic_vector(XLEN-1 downto 0);
    signal data_valid_reg   : std_logic;
    signal stall_del        : std_logic;

begin

    ------------------------------------------------------------------------------------------------
    ---                           Decision making control signals                                ---
    ------------------------------------------------------------------------------------------------

    -- Load or store is to be performed?
    do_load  <= '1' when i_skip = '0' and i_inst.opcode = LOAD  else '0';
    do_store <= '1' when i_skip = '0' and i_inst.opcode = STORE else '0';
    assert not(do_load = '1' and do_store = '1') 
        report "DO_LOAD=1 and DO_STORE=1" severity failure;

    -- Memory transaction aligned, i.e., it requires only a single memory access
    is_aligned <=
        '1' when i_inst.funct3 = "000"                               else  -- L(/S)B
        '1' when i_inst.funct3 = "001" and i_addr(0) = '0'           else  -- L(/S)H
        '1' when i_inst.funct3 = "010" and i_addr(1 downto 0) = "00" else  -- L(/S)W
        '1' when i_inst.funct3 = "100"                               else  -- LBU
        '1' when i_inst.funct3 = "101" and i_addr(0) = '0'           else  -- LHU
        '0';

    -- Quick loads and stores, that can be performed in a single cycle
    is_quick <= 
        '1' when is_aligned = '1' and do_store = '1' and i_inst.funct3 = "010"  else -- SW
        '1' when is_aligned = '1' and do_load = '1'                             else -- LB, LH, LW
        '0';

    -- Next transaction combinatorial logic
    next_transaction <=
        STORE_ALIGNED   when is_aligned = '1' and do_store = '1' and i_inst.funct3 /= "010"  else
        STORE_UNALIGNED when is_aligned = '0' and do_store = '1'                             else
        LOAD_UNALIGNED  when is_aligned = '0' and do_load  = '1'                              else
        WAITING;

    -- Non whole word data memory reads
    sign_extend <= not(inst_del.funct3(2));  -- Sign extension for LH, LB
    q_half(15 downto 0) <=
        i_mem_data(15 downto  0) when addr_del(1 downto 0) = "00" else
        i_mem_data(31 downto 16) when addr_del(1 downto 0) = "10" else
        (others => '-');
    q_half(31 downto 16) <= (others => q_half(15)) when sign_extend = '1' else (others => '0');
    q_quarter(7 downto 0) <=
        i_mem_data( 7 downto  0) when addr_del(1 downto 0) = "00" else
        i_mem_data(15 downto  8) when addr_del(1 downto 0) = "01" else
        i_mem_data(23 downto 16) when addr_del(1 downto 0) = "10" else
        i_mem_data(31 downto 24) when addr_del(1 downto 0) = "11" else
        (others => '-');
    q_quarter(31 downto 8) <= (others => q_quarter(7)) when sign_extend = '1' else (others => '0');

    -- Delayed stall signal
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            stall_del <= i_stall;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                          State machine for memory transactions                           ---
    ------------------------------------------------------------------------------------------------

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state <= WAITING;
                o_fault <= NONE;
            else
                case state is
                    when WAITING =>
                        state <= next_transaction;
                        o_fault <= NONE;
                    when LOAD_UNALIGNED =>
                        report "LOAD_UNALIGNED not implemented yet" severity failure;
                        o_fault <= MEMORY_ALIGNMENT_ERROR;
                    when STORE_UNALIGNED =>
                        report "STORE_UNALIGNED not implemented yet" severity failure;
                        o_fault <= MEMORY_ALIGNMENT_ERROR;
                    when STORE_ALIGNED =>
                        report "STORE_ALIGNED not implemented yet" severity failure;
                        o_fault <= MEMORY_ALIGNMENT_ERROR;
                end case;
            end if;
        end if;
    end process;

    -- Delayed instruction
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            inst_del <= i_inst;
            addr_del <= i_addr;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                               Data memory external interface                             ---
    ------------------------------------------------------------------------------------------------

    o_mem_addr <=
        i_addr when state = WAITING and is_quick = '1' else
        (others => '-');

    o_mem_data <=
        i_data when state = WAITING and is_quick = '1' else
        (others => '-');

    o_mem_we <=
        '1' when state = WAITING and is_quick = '1' and i_mem_ready = '1' and do_store = '1' else
        '0';

    o_mem_ena <=
        '1' when state = WAITING and is_quick = '1' and i_mem_ready = '1' and 
                 (do_store = '1' or do_load = '1') else
        '0';


    ------------------------------------------------------------------------------------------------
    ---                            Load-store unit external interface                            ---
    ------------------------------------------------------------------------------------------------

    mem_data_mux <=
        q_quarter   when inst_del.funct3(1 downto 0) = "00" else  -- LB
        q_half      when inst_del.funct3(1 downto 0) = "01" else  -- LH
        i_mem_data  when inst_del.funct3(1 downto 0) = "10" else  -- LW
        (others => '-');

    -- Saved memory data logic
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_stall = '1' and stall_del = '0' then
                mem_data_saved <= mem_data_mux;
            else
                mem_data_saved <= mem_data_saved;
            end if;
        end if;
    end process;

    -- Data valid logic
    process(all)
    begin
        if rising_edge(i_clk) then
            if i_stall = '1' then
                data_valid_reg <= data_valid_reg;
            else  -- i_stall = '0'
                if state = WAITING and is_quick = '1' and i_mem_ready = '1' then
                    data_valid_reg <= '1';
                else
                    data_valid_reg <= '0';
                end if;
            end if;
        end if;
    end process;
    o_data_valid <= data_valid_reg;

    -- Load instruction data selection logic
    process(all)
    begin
        if stall_del = '1' then
            o_data <= mem_data_saved;
        else
            o_data <= mem_data_mux;
        end if;
    end process;

end architecture riscy_load_store_rtl;
