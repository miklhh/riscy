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
        i_clk, i_rst : std_logic;
        
        -- Instruction memory port (synchronous to clk)
        o_instr_mem_ena     : out std_logic;
        o_instr_mem_addr    : out std_logic_vector(XLEN-1 downto 0);
        i_instr_mem_data    : in std_logic_vector(XLEN-1 downto 0);

        -- Data memory port (synchronous to clk)
        o_data_mem_ena      : out std_logic;
        o_data_mem_we       : out std_logic;
        o_data_mem_addr     : out std_logic_vector(XLEN-1 downto 0);
        o_data_mem_data     : out std_logic_vector(XLEN-1 downto 0);
        i_data_mem_data     : in std_logic_vector(XLEN-1 downto 0);

        -- CPU core fault and environment 
        o_core_fault        : out fault_type;
        o_ecall             : out std_logic;
        o_ecall_regs        : out regfile_vector_type
    );
end entity riscy_core;

architecture riscy_core_rtl of riscy_core is

    -- Program counter
    type PC_vector_type is array(0 to 4) of unsigned(XLEN-1 downto 0);
    signal PC_mux               : unsigned(XLEN-1 downto 0);
    signal PC                   : PC_vector_type;

    -- Instruction register pipeline
    type IR_pipeline_type is array(0 to 3) of std_logic_vector(XLEN-1 downto 0);
    type inst_pipeline_type is array(0 to 3) of inst_type;
    signal IR                   : IR_pipeline_type;
    signal inst                 : inst_pipeline_type;

    -- Data to/from register file
    type reg_pipeline_type is array(0 to 2) of std_logic_vector(XLEN-1 downto 0);
    signal regfile_data1       : std_logic_vector(XLEN-1 downto 0);
    signal regfile_data2       : std_logic_vector(XLEN-1 downto 0);
    signal rs1_data, rs2_data   : reg_pipeline_type;
    signal reg_i_data           : std_logic_vector(XLEN-1 downto 0);
    signal reg_i_adr            : unsigned(4 downto 0);
    signal reg_i_wen            : std_logic;
    signal regs                 : regfile_vector_type;  -- Readport for all regfile registers

    -- Register forwarding logic
    signal reg_fwd_a_p1         : std_logic;
    signal reg_fwd_a_p2         : std_logic;
    signal reg_fwd_b_p1         : std_logic;
    signal reg_fwd_b_p2         : std_logic;

    -- ALU signals
    type alu_out_vector_type is array(0 to 1) of std_logic_vector(XLEN-1 downto 0);
    signal alu_i_a              : std_logic_vector(XLEN-1 downto 0);
    signal alu_i_b              : std_logic_vector(XLEN-1 downto 0);
    signal alu_o                : alu_out_vector_type;

    -- Branch signals
    signal branch_take          : std_logic;
    signal branch_adr           : unsigned(XLEN-1 downto 0);

    -- CPU skip signal
    signal skip                 : std_logic_vector(0 to 3);
    signal skip_PC              : std_logic;

begin

    ------------------------------------------------------------------------------------------------
    ---                               CPU fault/environment handling                             ---
    ------------------------------------------------------------------------------------------------

    -- CPU faults
    process(inst(3), skip(3))
    begin
        o_core_fault <= NONE;
        -- Unimplemented instructions
        if skip(3) = '0' then
            case inst(3).opcode is
                when UNKNOWN => o_core_fault <= UNIMPLEMENTED_INSTRUCTION;
                when JALR => o_core_fault <= UNIMPLEMENTED_INSTRUCTION;
                when LOAD => o_core_fault <= UNIMPLEMENTED_INSTRUCTION;
                when STORE => o_core_fault <= UNIMPLEMENTED_INSTRUCTION;
                when AUIPC => o_core_fault <= UNIMPLEMENTED_INSTRUCTION;

                when others => o_core_fault <= NONE;
            end case;
        end if;
    end process;

    -- Environment calls
    o_ecall_regs <= regs;
    o_ecall <= '1' when IR(3) = x"00000073" else '0'; -- ECALL instruction

    ------------------------------------------------------------------------------------------------
    ---                                    Instruction fetch                                     ---
    ------------------------------------------------------------------------------------------------

    -- Program counter and instruction register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                PC <= (others => (others => '0'));
            else
                PC(0) <= PC_mux;
                PC(1 to 4) <= PC(0 to 3);
            end if;
        end if;
    end process;
    o_instr_mem_ena  <= not(i_rst);
    o_instr_mem_addr <= std_logic_vector(PC(0));
    PC_mux <= branch_adr when branch_take = '1' else PC(0)+4;

    -- Instruction register pipeline (the instruction memory acts as first IR register)
    IR(0) <= i_instr_mem_data;
    instr_pipeline : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                IR(1 to 3) <= (NOP, NOP, NOP);
            else
                IR(1 to 3) <= IR(0 to 2);
            end if;
        end if;
    end process;

    -- Instruction register RTL type
    process(IR)
    begin
        for i in 0 to 3 loop
            inst(i) <= to_inst(IR(i));
        end loop;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction decode                                    ---
    ------------------------------------------------------------------------------------------------

    -- Skip instruction logic
    skip_PC <= '1' when inst(0).opcode = JAL or inst(1).opcode = JAL else '0';
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            skip(0) <= skip_PC or branch_take or i_rst;
            skip(1) <= skip(0) or branch_take;
            skip(2 to 3) <= skip(1 to 2);
        end if;
    end process;

    -- Register file
    riscy_regfile: entity work.riscy_regfile
        port map (
            i_clk=>i_clk,
            i_rst=>i_rst,
            i_radr1=>to_inst(IR(0)).rs1,
            o_rdata1=>regfile_data1,
            i_radr2 =>to_inst(IR(0)).rs2,
            o_rdata2=>regfile_data2,
            i_wadr=>reg_i_adr,
            i_wena=>reg_i_wen,
            i_wdata=>reg_i_data,
            o_regs=>regs
        );

    -- Branch adder
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if inst(0).opcode = JAL then
                branch_adr <= unsigned( signed(PC(1)) + to_imm_j(IR(0)) );
            else
                branch_adr <= unsigned( signed(PC(1)) + to_imm_b(IR(0)) );
            end if;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction execute                                   ---
    ------------------------------------------------------------------------------------------------

    -- Register forwarding logic
    reg_fwd_a_p1 <= 
        '1' when skip(2) = '0' and (
                inst(2).opcode = OP     or 
                inst(2).opcode = OP_IMM or
                inst(2).opcode = LUI
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = OP_IMM or
                inst(1).opcode = LOAD   or
                inst(1).opcode = STORE  or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs1 = inst(2).rd
            )
        else '0';
    reg_fwd_a_p2 <=
        '1' when skip(3) = '0' and (
                inst(3).opcode = OP     or
                inst(3).opcode = OP_IMM or
                inst(3).opcode = LUI    or
                inst(3).opcode = LOAD
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = OP_IMM or
                inst(1).opcode = LOAD   or
                inst(1).opcode = STORE  or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs1 = inst(3).rd
            )
        else '0';
    reg_fwd_b_p1 <=
        '1' when skip(2) = '0' and (
                inst(2).opcode = OP     or
                inst(2).opcode = OP_IMM or
                inst(2).opcode = LUI
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs2 = inst(2).rd
            )
        else '0';
    reg_fwd_b_p2 <=
        '1' when skip(3) = '0' and (
                inst(3).opcode = OP     or
                inst(3).opcode = OP_IMM or
                inst(3).opcode = LUI    or
                inst(3).opcode = LOAD
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs2 = inst(3).rd
            )
        else '0';

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            rs1_data(1 to 2) <= rs1_data(0 to 1);
            rs2_data(1 to 2) <= rs2_data(0 to 1);
        end if;
    end process;
    rs1_data(0) <=
        alu_o(0) when reg_fwd_a_p1 = '1' else
        alu_o(1) when reg_fwd_a_p2 = '1' else
        regfile_data1;
    rs2_data(0) <=
        alu_o(0) when reg_fwd_b_p1 = '1' else
        alu_o(1) when reg_fwd_b_p2 = '1' else
        regfile_data2;


    -- Branch test unit
    riscy_branch_test: entity work.riscy_branch_test
    port map (
        i_clk=>i_clk,
        i_rst=>i_rst,
        i_opa=>rs1_data(0),
        i_opb=>rs2_data(0),
        i_opcode=>from_opcode(inst(1).opcode),
        i_funct3=>inst(1).funct3,
        i_funct7=>inst(1).funct7,
        i_skip=>skip(1),
        o_branch_take=>branch_take
    );

    -- ALU
    riscy_alu: entity work.riscy_alu
    port map (
        i_clk=>i_clk,
        i_rst=>i_rst,
        i_data1=>alu_i_a,
        i_data2=>alu_i_b,
        i_opcode=>IR(1)(6 downto 0),
        i_funct3=>IR(1)(14 downto 12),
        i_funct7=>IR(1)(31 downto 25),
        o_data=>alu_o(0)
    );
    process(i_clk) begin
        if rising_edge(i_clk) then
            alu_o(1) <= alu_o(0);
        end if;
    end process;

    alu_i_a <= rs1_data(0);
    alu_i_b <=
        std_logic_vector(to_imm_u(IR(1))) when inst(1).opcode = AUIPC       else
        std_logic_vector(to_imm_u(IR(1))) when inst(1).opcode = LUI         else
        std_logic_vector(to_imm_i(IR(1))) when inst(1).opcode = OP_IMM      else
        rs2_data(0);


    ------------------------------------------------------------------------------------------------
    ---                                      Data Memory                                         ---
    ------------------------------------------------------------------------------------------------

    o_data_mem_ena <= 
        '1' when skip(2) = '0' and (inst(2).opcode = LOAD or inst(2).opcode = STORE) else
        '0';
    o_data_mem_we  <= '1' when skip(2) = '0' and inst(2).opcode = STORE else '0';
    o_data_mem_addr <= alu_o(0);
    o_data_mem_data <= rs2_data(1);
    

    ------------------------------------------------------------------------------------------------
    ---                                       Writeback                                          ---
    ------------------------------------------------------------------------------------------------

    reg_i_adr <= inst(3).rd;
    reg_i_data <= 
        i_data_mem_data when inst(3).opcode = LOAD      else
        alu_o(1)        when inst(3).opcode = OP        else
        alu_o(1)        when inst(3).opcode = OP_IMM    else
        alu_o(1)        when inst(3).opcode = LUI       else
        (others => '-');
        
    reg_i_wen <= 
        '1' when skip(3) = '0' and (
                inst(3).opcode = LOAD    or 
                inst(3).opcode = OP      or
                inst(3).opcode = OP_IMM  or
                inst(3).opcode = LUI
            ) else 
        '0';


    ------------------------------------------------------------------------------------------------
    ---                                      Misc/other                                          ---
    ------------------------------------------------------------------------------------------------

end architecture riscy_core_rtl;
