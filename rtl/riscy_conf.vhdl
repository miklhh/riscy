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
        FENCE,
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
        funct3  : unsigned(2 downto 0);
        funct7  : unsigned(6 downto 0);
    end record inst_type;

    
    ------------------------------------------------------------------------------------------------
    ---                         Instruction/Immediate decoding utility                           ---
    ------------------------------------------------------------------------------------------------
    function to_inst(IR: std_logic_vector) return inst_type;
    function to_imm_i(inst: std_logic_vector) return signed;
    function to_imm_s(inst: std_logic_vector) return signed;
    function to_imm_b(inst: std_logic_vector) return signed;
    function to_imm_u(inst: std_logic_vector) return signed;
    function to_imm_j(inst: std_logic_vector) return signed;

    
    ------------------------------------------------------------------------------------------------
    ---                                    CPU faults types                                      ---
    ------------------------------------------------------------------------------------------------
    type fault_type is (
        NONE,
        UNIMPLEMENTED_INSTRUCTION
    );
    function fault_to_string(fault : fault_type) return string;


end package riscy_conf;


package body riscy_conf is

    function fault_to_string(fault : fault_type) return string is
    begin
        case fault is
            when NONE => return "NONE";
            when UNIMPLEMENTED_INSTRUCTION => return "UNIMPLEMENTED_INSTRUCTION";
            when others => 
                report "fault_to_string(): unknown fault" severity failure;
                return "";
        end case;
    end function;

    --
    -- Instruction decoding
    --
    function to_opcode(opcode_bin: std_logic_vector) return opcode is
    begin
        case opcode_bin is
            when "0110111" => return LUI;
            when "0010111" => return AUIPC;
            when "1101111" => return JAL;
            when "1100011" => return BRANCH;
            when "0000011" => return LOAD;
            when "0100011" => return STORE;
            when "0010011" => return OP_IMM;
            when "0110011" => return OP;
            when "0001111" => return FENCE;
            when "1110011" => return SYSTEM;
            when others => return UNKNOWN;
        end case;
    end function;

    function to_inst(IR: std_logic_vector) return inst_type is
        variable res : inst_type;
    begin
        res := (
            opcode => to_opcode(IR(6  downto  0)),
            rd =>     unsigned(IR(11 downto  7)),
            rs1 =>    unsigned(IR(19 downto 15)),
            rs2 =>    unsigned(IR(24 downto 20)),
            funct3 => unsigned(IR(14 downto 12)),
            funct7 => unsigned(IR(31 downto 25))
        );
        return res;
    end function;

    --
    -- All immediate decoding variants
    --
    function to_imm_i(inst: std_logic_vector) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(inst);
        return resize(insts(31 downto 31), 21) & insts(30 downto 20);
    end function;

    function to_imm_s(inst: std_logic_vector) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(inst);
        return resize(insts(31 downto 31), 21) & insts(30 downto 25) & insts(11 downto 7);
    end function;

    function to_imm_b(inst: std_logic_vector) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(inst);
        return 
            resize(insts(31 downto 31), 20) & insts(7) &
            insts(30 downto 25) & insts(11 downto 8) & '0';
    end function;

    function to_imm_u(inst: std_logic_vector) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(inst);
        return insts(31 downto 12) & x"000";
    end function;

    function to_imm_j(inst: std_logic_vector) return signed is
        variable insts : signed(XLEN-1 downto 0);
    begin
        insts := signed(inst);
        return
            resize(insts(31 downto 31), 12) & insts(19 downto 12) & insts(20) &
            insts(30 downto 21) & '0';
    end function;

end package body;
