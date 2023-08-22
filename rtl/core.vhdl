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
        i_instr_mem_ready   : in std_logic;
        o_instr_mem_addr    : out std_logic_vector(XLEN-1 downto 0);
        i_instr_mem_data    : in std_logic_vector(XLEN-1 downto 0);

        -- Data memory port (synchronous to clk)
        o_data_mem_ena      : out std_logic;
        o_data_mem_we       : out std_logic;
        i_data_mem_ready    : in std_logic;
        o_data_mem_addr     : out std_logic_vector(XLEN-1 downto 0);
        o_data_mem_data     : out std_logic_vector(XLEN-1 downto 0);
        i_data_mem_data     : in std_logic_vector(XLEN-1 downto 0);

        -- CPU core fault and environment 
        o_core_fault        : out fault_type;
        o_ecall             : out std_logic;
        o_ecall_regs        : out regfile_vector_type;

        -- Stalling injection
        i_stall             : in std_logic_vector(0 to 4)
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
    signal IR_saved             : std_logic_vector(XLEN-1 downto 0);
    signal inst                 : inst_pipeline_type;

    -- Register file signals (rs1_data and rs2_data always contain correctly forwarded data)
    type reg_pipeline_type is array(0 to 2) of std_logic_vector(XLEN-1 downto 0);
    signal regfile_radr1        : unsigned(4 downto 0);
    signal regfile_radr2        : unsigned(4 downto 0);
    signal regfile_data1        : std_logic_vector(XLEN-1 downto 0);
    signal regfile_data2        : std_logic_vector(XLEN-1 downto 0);
    signal rs1_data, rs2_data   : reg_pipeline_type;
    signal regfile_i_data       : std_logic_vector(XLEN-1 downto 0);
    signal regfile_i_adr        : unsigned(4 downto 0);
    signal regfile_i_wen        : std_logic;
    signal regs                 : regfile_vector_type;  -- Readport for all regfile registers

    -- Register forwarding logic.
    -- * bit 0: forward from EX/MEM (higher priority)
    -- * bit 1: forward from MEM/WB (lower priority)
    signal reg_fwd_rs1          : std_logic_vector(1 downto 0);
    signal reg_fwd_rs2          : std_logic_vector(1 downto 0);

    -- ALU signals
    type alu_out_vector_type is array(0 to 1) of std_logic_vector(XLEN-1 downto 0);
    signal alu_i_a              : std_logic_vector(XLEN-1 downto 0);
    signal alu_i_b              : std_logic_vector(XLEN-1 downto 0);
    signal alu_o                : alu_out_vector_type;

    -- Branch signals
    signal branch_take0         : std_logic;  -- Take branch (lower priority)
    signal branch_take1         : std_logic;  -- Take branch (higher priority)
    signal branch_adr0          : unsigned(XLEN-1 downto 0);
    signal branch_adr1          : unsigned(XLEN-1 downto 0);

    -- CPU skip instruction signal
    signal skip                 : std_logic_vector(0 to 3);
    signal skip_PC              : std_logic;

    -- CPU stall signals
    signal stall                : std_logic_vector(0 to 4);
    signal stall_del            : std_logic_vector(0 to 4);

    -- Load store unit signals
    signal load_store_o_data    : std_logic_vector(XLEN-1 downto 0);
    signal load_store_i_data    : std_logic_vector(XLEN-1 downto 0);
    signal load_store_i_addr    : std_logic_vector(XLEN-1 downto 0);
    signal load_store_o_valid   : std_logic;
    signal load_store_fault     : fault_type;
    signal load_store_o_stall   : std_logic;  -- Load-store unit requests stalling
    signal id_load_stall        : std_logic;  -- ID stage: stall due to Read-after-Load
    signal id_load_stall_rs1    : std_logic;
    signal id_load_stall_rs2    : std_logic;

begin

    ------------------------------------------------------------------------------------------------
    ---                               CPU fault/environment handling                             ---
    ------------------------------------------------------------------------------------------------

    -- CPU faults
    process(all)
    begin
        -- Default: no fault
        o_core_fault <= NONE;

        -- Unimplemented instructions
        if skip(3) = '0' then
            case inst(3).opcode is
                when UNKNOWN => o_core_fault <= UNIMPLEMENTED_INSTRUCTION_ERROR;
                when others => o_core_fault <= NONE;
            end case;
        end if;

        -- Memory alignment fault
        if load_store_fault /= NONE then
            o_core_fault <= load_store_fault;
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
                PC(0) <= PC_mux;  -- Stalling of PC(0) is handeled in PC mux
                if stall(1) = '1' then PC(1) <= PC(1); else PC(1) <= PC(0); end if;
                if stall(2) = '1' then PC(2) <= PC(2); else PC(2) <= PC(1); end if;
                if stall(3) = '1' then PC(3) <= PC(3); else PC(3) <= PC(2); end if;
                if stall(4) = '1' then PC(4) <= PC(4); else PC(4) <= PC(3); end if;
            end if;
        end if;
    end process;
    o_instr_mem_ena  <= not(i_rst);
    o_instr_mem_addr <= std_logic_vector(PC(0));
    PC_mux <= 
        branch_adr1 when branch_take1 = '1' else
        branch_adr0 when branch_take0 = '1' else
        PC(0)       when stall(0) = '1'     else
        PC(0)+4;

    -- Instruction register pipeline (the instruction memory acts as first IR register)
    instr_pipeline : process(i_clk)
        -- IR(0) is a combinatorial signal assigned outside of this process. The local variable
        -- IR_local is used to mitigate multiple drivers of IR(0) that would occur due to the the
        -- logest static prefix rule and indexing of IR(idx) in the process loop.
        variable IR_local : IR_pipeline_type;
    begin

        if rising_edge(i_clk) then
            if i_rst = '1' then
                IR(1 to 3) <= (others => (others => '0'));
            else
                --
                -- The stalling logic works as following on the instruction register pipeline:
                --   * If the stalling signal corresponding to a pipeline stage is SET (=1),
                --     then the corresponding instruction register (IR) MUST keep its value.
                --   * If the stalling signal corresponding to a pipeline stage is UN-SET (=0),
                --     then the corresponding instruction register (IR) will take its value from
                --     the previous step in the instruction register pipeline (IR-1), unless the
                --     previous step has its stall signal set, in which case the instruction
                --     register (IR) will be set to NOP.
                --
                -- NOTE: stall(n) corresponds to IR(n-1)
                --
                IR_local := (others => (others => '1'));
                for idx in 1 to 3 loop
                    if stall(idx+1) = '0' then
                        if stall(idx) = '0' then
                            IR_local(idx) := IR(idx-1);
                        else
                            IR_local(idx) := NOP;
                        end if;
                    else -- stall(idx+1) = '1'
                        IR_local(idx) := IR(idx);
                    end if;
                end loop;

                -- Assignment of the real IR signal
                IR(1 to 3) <= IR_local(1 to 3);
            end if;
        end if;
    end process;

    -- Instruction register RTL type
    process(all)
    begin
        for i in 0 to 3 loop
            inst(i) <= to_inst(IR(i));
        end loop;
    end process;

    -- Logic for selecting the first instruction of the instruction pipeline
    process(all)
    begin
        if stall_del(1) = '1' then
            -- Prio 1: Use the preserved instruction
            IR(0) <= IR_saved;
        elsif stall_del(0) = '1' then
            -- Prio 2: PC stalled previous cycle, data is invalid
            IR(0) <= NOP;
        else
            -- Prio 3: The instruction is available from the instruction memory
            IR(0) <= i_instr_mem_data;
        end if;
    end process;

    -- Saved instruction logic
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if stall(1) = '1' and stall_del(1) = '0' then
                IR_saved <= i_instr_mem_data;
            else
                IR_saved <= IR_saved;
            end if;
        end if;
    end process;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction decode                                    ---
    ------------------------------------------------------------------------------------------------

    -- Skip instruction logic
    skip_PC <= 
        '1' when 
            (inst(0).opcode = JAL  and skip(0) = '0') or 
            (inst(1).opcode = JAL  and skip(1) = '0') or
            (inst(0).opcode = JALR and skip(0) = '0') or
            (inst(1).opcode = JALR and skip(1) = '0') or
            (inst(2).opcode = JALR and skip(2) = '0')
        else '0';
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                skip(0 to 3) <= (others => '1');
            else
                skip(0) <= (stall(1) and skip(0)) or (not(stall(1)) and skip_PC) or branch_take0;
                skip(1) <= (stall(2) and skip(1)) or (not(stall(2)) and (skip(0) or branch_take0));
                skip(2) <= (stall(3) and skip(2)) or (not(stall(3)) and skip(1));
                skip(3) <= (stall(4) and skip(3)) or (not(stall(4)) and skip(2));
            end if;
        end if;
    end process;

    -- Register file
    riscy_regfile: entity work.riscy_regfile
        port map (
            i_clk=>i_clk,
            i_rst=>i_rst,
            i_radr1=>regfile_radr1,
            o_rdata1=>regfile_data1,
            i_radr2 =>regfile_radr2,
            o_rdata2=>regfile_data2,
            i_wadr=>regfile_i_adr,
            i_wena=>regfile_i_wen,
            i_wdata=>regfile_i_data,
            o_regs=>regs
        );
    regfile_radr1 <= inst(1).rs1 when stall(1) = '1' else inst(0).rs1;
    regfile_radr2 <= inst(1).rs2 when stall(1) = '1' else inst(0).rs2;

    -- Branch address selection
    process(i_clk)
        variable sum         : unsigned(XLEN-1 downto 0);
        variable immediate   : signed(XLEN-1 downto 0);
    begin
        if rising_edge(i_clk) then
            case inst(0).opcode is
                when JAL     => immediate := to_imm_j(IR(0));
                when BRANCH  => immediate := to_imm_b(IR(0));
                -- JALR branch address evaluated in ALU
                when others  => immediate := (others => '-');
            end case;
            sum := unsigned( signed(PC(1)) + immediate );
            branch_adr0(0) <= '0';
            if stall(1) = '1' then
                branch_adr0(XLEN-1 downto 1) <= branch_adr0(XLEN-1 downto 1);
            else
                branch_adr0(XLEN-1 downto 1) <= sum(XLEN-1 downto 1);
            end if;
        end if;
    end process;
    branch_adr1 <= unsigned(alu_o(0));  -- JALR branch address evaluated in ALU 


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction execute                                   ---
    ------------------------------------------------------------------------------------------------

    -- Register forwarding logic
    reg_fwd_rs1(0) <= 
        '1' when skip(2) = '0' and (
                inst(2).opcode = OP     or 
                inst(2).opcode = OP_IMM or
                inst(2).opcode = LUI    or
                inst(2).opcode = JALR   or
                inst(2).opcode = AUIPC
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = OP_IMM or
                inst(1).opcode = LOAD   or
                inst(1).opcode = STORE  or
                inst(1).opcode = JALR   or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs1 = inst(2).rd
            ) and (
                inst(1).rs1 /= 0
            )
        else '0';
    reg_fwd_rs1(1) <=
        '1' when skip(3) = '0' and (
                inst(3).opcode = OP     or
                inst(3).opcode = OP_IMM or
                inst(3).opcode = LUI    or
                inst(3).opcode = JALR   or
                inst(3).opcode = AUIPC  or
                inst(3).opcode = LOAD
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = OP_IMM or
                inst(1).opcode = LOAD   or
                inst(1).opcode = STORE  or
                inst(1).opcode = JALR   or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs1 = inst(3).rd
            ) and (
                inst(1).rs1 /= 0
            )
        else '0';
    reg_fwd_rs2(0) <=
        '1' when skip(2) = '0' and (
                inst(2).opcode = OP     or
                inst(2).opcode = OP_IMM or
                inst(2).opcode = LUI    or
                inst(2).opcode = JALR   or
                inst(2).opcode = AUIPC
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = STORE  or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs2 = inst(2).rd
            ) and (
                inst(1).rs2 /= 0
            )
        else '0';
    reg_fwd_rs2(1) <=
        '1' when skip(3) = '0' and (
                inst(3).opcode = OP     or
                inst(3).opcode = OP_IMM or
                inst(3).opcode = LUI    or
                inst(3).opcode = JALR   or
                inst(3).opcode = AUIPC  or
                inst(3).opcode = LOAD
            ) and (
                inst(1).opcode = OP     or
                inst(1).opcode = STORE  or
                inst(1).opcode = BRANCH
            ) and (
                inst(1).rs2 = inst(3).rd
            ) and (
                inst(1).rs2 /= 0
            )
        else '0';

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if stall(3) = '1' then
                rs1_data(1) <= rs1_data(1);
                rs2_data(1) <= rs2_data(1);
            else
                rs1_data(1) <= rs1_data(0);
                rs2_data(1) <= rs2_data(0);
            end if;
            if stall(4) = '1' then
                rs1_data(2) <= rs1_data(2);
                rs2_data(2) <= rs2_data(2);
            else
                rs1_data(2) <= rs1_data(1);
                rs2_data(2) <= rs2_data(1);
            end if;
        end if;
    end process;
    rs1_data(0) <=
        alu_o(0)            when reg_fwd_rs1(0) = '1'                             else
        alu_o(1)            when reg_fwd_rs1(1) = '1' and inst(3).opcode /= LOAD  else
        load_store_o_data   when reg_fwd_rs1(1) = '1' and inst(3).opcode  = LOAD  else
        regfile_data1;
    rs2_data(0) <=
        alu_o(0)            when reg_fwd_rs2(0) = '1' else
        alu_o(1)            when reg_fwd_rs2(1) = '1' and inst(3).opcode /= LOAD  else
        load_store_o_data   when reg_fwd_rs2(1) = '1' and inst(3).opcode  = LOAD  else
        regfile_data2;


    -- Branch test unit
    riscy_branch_test: entity work.riscy_branch_test
    port map (
        i_clk=>i_clk,
        i_rst=>i_rst,
        i_stall=>stall(3),
        i_opa=>rs1_data(0),
        i_opb=>rs2_data(0),
        i_opcode=>from_opcode(inst(1).opcode),
        i_funct3=>inst(1).funct3,
        i_funct7=>inst(1).funct7,
        i_skip=>skip(1),
        o_branch_take0=>branch_take0,
        o_branch_take1=>branch_take1
    );

    -- ALU
    riscy_alu: entity work.riscy_alu
    port map (
        i_clk=>i_clk,
        i_rst=>i_rst,
        i_stall=>stall(2),
        i_data1=>alu_i_a,
        i_data2=>alu_i_b,
        i_opcode=>IR(1)(6 downto 0),
        i_funct3=>IR(1)(14 downto 12),
        i_funct7=>IR(1)(31 downto 25),
        o_data=>alu_o(0)
    );
    process(i_clk) begin
        if rising_edge(i_clk) then
            if stall(4) = '1' then
                alu_o(1) <= alu_o(1);
            else
                alu_o(1) <= alu_o(0);
            end if;
        end if;
    end process;

    alu_i_a <= 
        std_logic_vector(PC(2)) when inst(1).opcode = AUIPC else
        rs1_data(0);
    alu_i_b <=
        std_logic_vector(to_imm_u(IR(1))) when inst(1).opcode = AUIPC       else
        std_logic_vector(to_imm_u(IR(1))) when inst(1).opcode = LUI         else
        std_logic_vector(to_imm_i(IR(1))) when inst(1).opcode = OP_IMM      else
        std_logic_vector(to_imm_i(IR(1))) when inst(1).opcode = JALR        else
        std_logic_vector(to_imm_i(IR(1))) when inst(1).opcode = LOAD        else
        std_logic_vector(to_imm_s(IR(1))) when inst(1).opcode = STORE       else
        rs2_data(0);

    -- Load stalling
    id_load_stall <= id_load_stall_rs1 or id_load_stall_rs2;
    id_load_stall_rs1 <= 
        '1' when skip(1) = '0' and skip(2) = '0' and (
                inst(1).opcode = LOAD
            ) and (
                inst(0).opcode = OP     or
                inst(0).opcode = OP_IMM or
                inst(0).opcode = LOAD   or
                inst(0).opcode = STORE  or
                inst(0).opcode = JALR   or
                inst(0).opcode = BRANCH
            ) and (
                inst(0).rs1 = inst(1).rd
            ) and (
                inst(0).rs1 /= 0
            )
        else '0';
    id_load_stall_rs2 <=
        '1' when skip(1) = '0' and skip(2) = '0' and (
                inst(1).opcode = LOAD
            ) and (
                inst(0).opcode = OP     or
                inst(0).opcode = STORE  or
                inst(0).opcode = BRANCH
            ) and (
                inst(0).rs2 = inst(1).rd
            ) and (
                inst(0).rs2 /= 0
            )
        else '0';


    ------------------------------------------------------------------------------------------------
    ---                                      Data Memory                                         ---
    ------------------------------------------------------------------------------------------------

    -- Load store unit talking to the memory
    riscy_load_store_inst: entity work.riscy_load_store
    port map (
        -- System
        i_clk=>i_clk,
        i_rst=>i_rst,
        i_skip=>skip(2),
        i_inst=>inst(2),
        i_stall=>stall(4),              -- WB stage: stall(4)
        o_stall=>load_store_o_stall,    -- MEM stage: stall(3)
        i_addr=>load_store_i_addr,
        i_data=>load_store_i_data,

        -- Data memory interface
        i_mem_ready=>i_data_mem_ready,
        i_mem_data=>i_data_mem_data,
        o_mem_ena=>o_data_mem_ena,
        o_mem_data=>o_data_mem_data,
        o_mem_addr=>o_data_mem_addr,
        o_mem_we=>o_data_mem_we,

        -- Load store output
        o_data=>load_store_o_data,
        o_data_valid=>load_store_o_valid,

        -- Fault
        o_fault=>load_store_fault
    );
    load_store_i_data <= rs2_data(1);
    load_store_i_addr <= alu_o(0);
    

    ------------------------------------------------------------------------------------------------
    ---                                       Writeback                                          ---
    ------------------------------------------------------------------------------------------------

    regfile_i_adr <= inst(3).rd;
    regfile_i_data <= 
        load_store_o_data       when inst(3).opcode = LOAD      else
        alu_o(1)                when inst(3).opcode = OP        else
        alu_o(1)                when inst(3).opcode = OP_IMM    else
        alu_o(1)                when inst(3).opcode = LUI       else
        alu_o(1)                when inst(3).opcode = AUIPC     else
        std_logic_vector(PC(3)) when inst(3).opcode = JALR      else
        std_logic_vector(PC(3)) when inst(3).opcode = JAL       else
        (others => '-');
    regfile_i_wen <= 
        '1' when skip(3) = '0' and (
               (inst(3).opcode = LOAD and load_store_o_valid = '1') or 
                inst(3).opcode = OP      or
                inst(3).opcode = OP_IMM  or
                inst(3).opcode = JAL     or
                inst(3).opcode = JALR    or
                inst(3).opcode = LUI     or
                inst(3).opcode = AUIPC
            ) else 
        '0';


    ------------------------------------------------------------------------------------------------
    ---                                      Misc/other                                          ---
    ------------------------------------------------------------------------------------------------

    --
    -- Pipeline stalling logic:
    -- Stalling of a pipeline stage applies backward pressure to the previous stages in the
    -- pipeline. It is generally safe to apply stalling externally to any pipeline stage.
    --
    stall(0) <= i_stall(0) or stall(1) or not(i_instr_mem_ready);  -- Stall(0): IF
    stall(1) <= i_stall(1) or stall(2) or id_load_stall;           -- Stall(1): ID
    stall(2) <= i_stall(2) or stall(3);                            -- Stall(2): EX
    stall(3) <= i_stall(3) or stall(4) or load_store_o_stall;      -- Stall(3): MEM
    stall(4) <=                                                    -- Stall(4): WB
        '1' when i_stall(4) = '1'                                   else
        '1' when i_data_mem_ready = '0' and inst(2).opcode = LOAD   else
        '1' when i_data_mem_ready = '0' and inst(2).opcode = STORE  else
        '0';
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            stall_del <= stall;
        end if;
    end process;


end architecture riscy_core_rtl;
