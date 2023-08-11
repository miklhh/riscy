--
-- Riscy RISC-V CPU configurations
-- Author: Mikael Henriksson (2023)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package riscy_conf is

    ------------------------------------------------------------------------------------------------
    ---                                 RISC-V processor bit-width                               ---
    ------------------------------------------------------------------------------------------------
    constant XLEN : integer := 32;


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction opcodes                                   ---
    ------------------------------------------------------------------------------------------------
    type opcode is (
        UNKNOWN,
        AUIPC,
        LUI,
        OP_IMM,
        OP,
        BRANCH,
        JAL,
        JALR,
        LOAD,
        STORE,
        MISC_MEM,
        SYSTEM
    );


    ------------------------------------------------------------------------------------------------
    ---                                    Instruction fields                                    ---
    ------------------------------------------------------------------------------------------------
    type inst_type is record
        opcode  : opcode;
        rd      : unsigned(4 downto 0);
        rs1     : unsigned(4 downto 0);
        rs2     : unsigned(4 downto 0);
        funct3  : std_logic_vector(2 downto 0);
        funct7  : std_logic_vector(6 downto 0);
    end record inst_type;
    function to_opcode(opcode_bin: std_logic_vector(6 downto 0)) return opcode;
    function from_opcode(opc: opcode) return std_logic_vector;
   

    ------------------------------------------------------------------------------------------------
    ---                         Instruction/Immediate decoding utility                           ---
    ------------------------------------------------------------------------------------------------
    function to_inst(IR: std_logic_vector(XLEN-1 downto 0)) return inst_type;
    function to_imm_i(IR: std_logic_vector(XLEN-1 downto 0)) return signed;
    function to_imm_s(IR: std_logic_vector(XLEN-1 downto 0)) return signed;
    function to_imm_b(IR: std_logic_vector(XLEN-1 downto 0)) return signed;
    function to_imm_u(IR: std_logic_vector(XLEN-1 downto 0)) return signed;
    function to_imm_j(IR: std_logic_vector(XLEN-1 downto 0)) return signed;


    ------------------------------------------------------------------------------------------------
    ---                                     Instructions                                         ---
    ------------------------------------------------------------------------------------------------
    constant NOP : std_logic_vector(XLEN-1 downto 0) := x"00000013";  -- addi 0,0,0
    

    ------------------------------------------------------------------------------------------------
    ---                                    Misc data types                                       ---
    ------------------------------------------------------------------------------------------------
    type regfile_vector_type is array(0 to 32-1) of std_logic_vector(XLEN-1 downto 0);

    ------------------------------------------------------------------------------------------------
    ---                                    CPU faults types                                      ---
    ------------------------------------------------------------------------------------------------
    type fault_type is (
        NONE,
        UNIMPLEMENTED_INSTRUCTION
    );

end package riscy_conf;


package body riscy_conf is

    --
    -- Instruction decoding
    --
    function to_opcode(opcode_bin: std_logic_vector(6 downto 0)) return opcode is
    begin
        case opcode_bin is
            when "0110111" => return LUI;
            when "0010111" => return AUIPC;
            when "1101111" => return JAL;
            when "1100111" => return JALR;
            when "1100011" => return BRANCH;
            when "0000011" => return LOAD;
            when "0100011" => return STORE;
            when "0010011" => return OP_IMM;
            when "0110011" => return OP;
            when "1110011" => return SYSTEM;
            when "0001111" => return MISC_MEM;
            when others => return UNKNOWN;
        end case;
    end function;

    function from_opcode(opc: opcode) return std_logic_vector is
    begin
        case opc is
            when LUI => return      "0110111";
            when AUIPC => return    "0010111";
            when JAL => return      "1101111";
            when JALR => return     "1100111";
            when BRANCH => return   "1100011";
            when LOAD => return     "0000011";
            when STORE => return    "0100011";
            when OP_IMM => return   "0010011";
            when OP => return       "0110011";
            when SYSTEM => return   "1110011";
            when MISC_MEM => return "0001111";
            when others => return   "0010011";
        end case;
    end function;

    function to_inst(IR: std_logic_vector(XLEN-1 downto 0)) return inst_type is
        variable res : inst_type;
    begin
        res := (
            opcode => to_opcode(IR(6  downto  0)),
            rd =>     unsigned(IR(11 downto  7)),
            rs1 =>    unsigned(IR(19 downto 15)),
            rs2 =>    unsigned(IR(24 downto 20)),
            funct3 => IR(14 downto 12),
            funct7 => IR(31 downto 25)
        );
        return res;
    end function;

    --
    -- All immediate decoding variants
    --
    function to_imm_i(IR: std_logic_vector(XLEN-1 downto 0)) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(IR);
        return resize(insts(31 downto 31), 21) & insts(30 downto 20);
    end function;

    function to_imm_s(IR: std_logic_vector(XLEN-1 downto 0)) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(IR);
        return resize(insts(31 downto 31), 21) & insts(30 downto 25) & insts(11 downto 7);
    end function;

    function to_imm_b(IR: std_logic_vector(XLEN-1 downto 0)) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(IR);
        return 
            resize(insts(31 downto 31), 20) & insts(7) &
            insts(30 downto 25) & insts(11 downto 8) & '0';
    end function;

    function to_imm_u(IR: std_logic_vector(XLEN-1 downto 0)) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(IR);
        return insts(31 downto 12) & x"000";
    end function;

    function to_imm_j(IR: std_logic_vector(XLEN-1 downto 0)) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(IR);
        return
            resize(insts(31 downto 31), 12) & insts(19 downto 12) & insts(20) &
            insts(30 downto 21) & '0';
    end function;

end package body;
