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

    -- Program counter
    type PC_vector_type is array(0 to 4) of unsigned(XLEN-1 downto 0);
    signal PC_mux               : unsigned(XLEN-1 downto 0);
    signal PC                   : PC_vector_type;

    -- Instruction register pipeline
    type IR_pipeline_type is array(0 to 3) of std_logic_vector(XLEN-1 downto 0);
    type IR_debug_pipeline_type is array(0 to 3) of inst_type;
    signal IR                   : IR_pipeline_type;
    signal IR_debug             : IR_debug_pipeline_type;

    -- Data to/from register file
    signal rs1_data, rs2_data   : std_logic_vector(XLEN-1 downto 0);
    signal reg_i_data           : std_logic_vector(XLEN-1 downto 0);
    signal reg_i_adr            : unsigned(4 downto 0);
    signal reg_i_wen            : std_logic;

    -- Branch signals
    signal branch_take          : std_logic;
    signal branch_adr           : unsigned(XLEN-1 downto 0);

    -- CPU skip signal
    signal skip                : std_logic_vector(0 to 3);

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
                PC <= (others => (others => '0'));
            else
                PC(0) <= PC_mux;
                PC(1 to 4) <= PC(0 to 3);
            end if;
        end if;
    end process;
    o_instr_mem_ena  <= not(rst);
    o_instr_mem_addr <= std_logic_vector(PC(0));
    PC_mux <= branch_adr when branch_take = '1' else PC(0)+4;

    -- Instruction register pipeline (the instruction memory acts as first IR register)
    IR(0) <= i_instr_mem_data;
    instr_pipeline : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                IR(1 to 3) <= (NOP, NOP, NOP);
            else
                IR(1 to 3) <= IR(0 to 2);
                if skip(2) = '1' then
                    IR(2) <= NOP;
                end if;
            end if;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction decode                                    ---
    ------------------------------------------------------------------------------------------------

    -- Skip instruction logic
    skip(0) <= '1' when to_inst(IR(0)).opcode = JAL or to_inst(IR(1)).opcode = JAL else '0';
    process(clk)
    begin
        if rising_edge(clk) then
            skip(1 to 3) <= skip(0 to 2);
        end if;
    end process;

    -- Register file
    riscy_regfile: entity work.riscy_regfile
        port map (
            clk=>clk,
            rst=>rst,
            i_radr1=>to_inst(IR(0)).rs1,
            o_rdata1=>rs1_data,
            i_radr2 =>to_inst(IR(0)).rs2,
            o_rdata2=>rs2_data,
            i_wadr=>reg_i_adr,
            i_wena=>reg_i_wen,
            i_wdata=>reg_i_data
        );

    -- Branching adder (J-type immediate if JAL and B-type immediate if BRANCH)
    process(clk)
    begin
        if rising_edge(clk) then
            if to_inst(IR(0)).opcode = JAL then
                branch_adr <= unsigned( signed(PC(1)) + to_imm_j(IR(0)) );
            else -- OPCODE.BRNACH
                branch_adr <= unsigned( signed(PC(1)) + to_imm_b(IR(0)) );
            end if;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction execute                                   ---
    ------------------------------------------------------------------------------------------------

    -- Branch take logic
    process(IR)
    begin
        if to_inst(IR(1)).opcode = JAL then
            branch_take <= '1';
        else
            branch_take <= '0';
        end if;
    end process;

    -- ALU
    -- TODO:

    ------------------------------------------------------------------------------------------------
    ---                                        Memory                                            ---
    ------------------------------------------------------------------------------------------------

    

    ------------------------------------------------------------------------------------------------
    ---                                       Writeback                                          ---
    ------------------------------------------------------------------------------------------------
    reg_i_adr <= to_inst(IR(3)).rd;
    reg_i_data <= std_logic_vector(to_imm_i(IR(3)));
    reg_i_wen <= '1' when to_inst(IR(3)).opcode = OP_IMM else '0';


    ------------------------------------------------------------------------------------------------
    ---                                      Misc/other                                          ---
    ------------------------------------------------------------------------------------------------

    -- Instruction register debuging
    process(IR)
    begin
        for i in 0 to 3 loop
            IR_debug(i) <= to_inst(IR(i));
        end loop;
    end process;

end architecture riscy_core_rtl;
