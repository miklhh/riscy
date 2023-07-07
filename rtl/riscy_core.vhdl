--
-- Riscy RISC-V CPU core
-- Author: Mikael Henriksson (2023)
--
library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_core is
    generic(
        hartid : integer := 0
    );
    port(
        clk, rst : std_logic;
        
        -- Instruction memory port (synchronous to clk)
        o_instr_mem_ena     : out std_logic;
        o_instr_mem_addr    : out std_logic_vector(XLEN-1 downto 0);
        i_instr_mem_data    : in std_logic_vector(XLEN-1 downto 0);

        -- CPU core fault
        o_fault             : out fault_type
    );
end entity riscy_core;

architecture riscy_core_rtl of riscy_core is
    signal PC : unsigned(XLEN-1 downto 0);

    -- Instruction register pipeline
    type IR_pipeline_type is array(0 to 3) of std_logic_vector(XLEN-1 downto 0);
    signal IR : IR_pipeline_type;

    -- Data from register file
    signal rs1_data : std_logic_vector(XLEN-1 downto 0);
    signal rs2_data : std_logic_vector(XLEN-1 downto 0);
begin

    o_fault <= NONE;

    ------------------------------------------------------------------------------------------------
    ---                                    Instruction fetch                                     ---
    ------------------------------------------------------------------------------------------------
    -- Program counter and instruction register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                PC <= (others => '0');
            else
                PC <= PC + 4;
            end if;
        end if;
    end process;
    o_instr_mem_ena  <= not(rst);
    o_instr_mem_addr <= std_logic_vector(PC);

    -- Instruction register pipeline
    IR(0) <= i_instr_mem_data;
    instr_pipeline : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                IR(1 to 3) <= (others => (others => '0'));
            else
                IR(1 to 3) <= IR(0 to 2);
            end if;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction decode                                    ---
    ------------------------------------------------------------------------------------------------
    -- Register file
    riscy_regfile: entity work.riscy_regfile
        port map (
            clk=>clk,
            rst=>rst,
            i_radr1=>to_inst(IR(0)).rs1,
            o_rdata1=>rs1_data,
            i_radr2 =>to_inst(IR(0)).rs2,
            o_rdata2=>rs2_data,
            i_wadr=>(others => '0'),
            i_wena=>'0',
            i_wdata=>(others => '0') 
        );

    -- Branching adder (J-type immediate if JAL and B-type immediate if BRANCH)
    --process(clk)
    --begin
    --    if rising_edge(clk) then
    --        if to_inst(IR(0)).opcode = opcode.JAL then
    --            branch_target_adr <= PC + to_imm_j(IR(0));
    --        else -- OPCODE.BRNACH
    --            branch_target_adr <= PC + to_imm_b(IR(0));
    --        end if;
    --    end if;
    --end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction execute                                   ---
    ------------------------------------------------------------------------------------------------


    ------------------------------------------------------------------------------------------------
    ---                                        Memory                                            ---
    ------------------------------------------------------------------------------------------------


    ------------------------------------------------------------------------------------------------
    ---                                       Writeback                                          ---
    ------------------------------------------------------------------------------------------------

end architecture riscy_core_rtl;
