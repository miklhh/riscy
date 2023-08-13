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
    generic(
        hartid : integer := 0
    );
    port(
        i_clk, i_rst : in std_logic;

        -- Back pressure handling
        i_wait      : in std_logic;  -- From descendat (next) pipeline stage
        o_wait      : out std_logic;  -- To ascendant (previous) pipeline stage

        -- Input from execution stage
        i_skip      : in std_logic;  -- Skip this instruction
        i_inst      : in inst_type;  -- Instruction to executre
        i_addr      : in std_logic_vector(XLEN-1 downto 0);  -- Input address
        i_data      : in std_logic_vector(XLEN-1 downto 0);  -- Input data

        -- Data memory interface
        i_mem_ready : in std_logic;
        i_mem_data  : in std_logic;
        i_mem_valid : in std_logic;
        o_mem_data  : out std_logic_vector(XLEN-1 downto 0);
        o_mem_addr  : out std_logic_vector(XLEN-1 downto 0);

        -- Output to write back stage
        o_data      : out std_logic_vector(XLEN-1 downto 0);  -- Output data
        o_data_valid: out std_logic  -- Output data is valid
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

    signal do_load          : std_logic;  -- Perform a load operation
    signal do_store         : std_logic;  -- Perform a store operation
begin

    -- Load or store is to be performed?
    do_load  <= '1' when i_skip = '0' and i_wait = '0' and i_inst.opcode = LOAD  else '0';
    do_store <= '1' when i_skip = '0' and i_wait = '0' and i_inst.opcode = STORE else '0';

    -- Memory transaction aligned?
    is_aligned <= ???;

    -- Next transaction logic
    process(i_wait, i_skip, i_inst)
    begin
        if do_load = '0' or do_store = '0' then
            next_transaction <= WAITING;
        else 

        end if;
    end process;

    -- Quick aligned loads and aligned XLEN stores
    process(i_wait, i_skip, i_inst)
    begin
        if state /= WAITING or is_aligned /= '1' or (do_load /= '1' and do_store /= '1') then
            null;
        elsif do_load = '1' then
            q_o_mem_data <= i_data;
            q_o_mem_addr <= i_addr;
        else 
        -- TODO: Test if this this is

        end if;
    end process;
    

    -- State machine
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state <= WAITING;
            else
                case state is
                    when WAITING =>
                        state <= next_transaction;
                    when LOAD_UNALIGNED =>
                        null;
                    when STORE_ALIGNED =>
                        null;
                    when STORE_UNALIGNED =>
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture riscy_load_store_rtl;
