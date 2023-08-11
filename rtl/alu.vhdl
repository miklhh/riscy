--
-- Riscy RISC-V arithmetic and logic unit
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_alu is
    port(
        i_clk, i_rst : in std_logic;

        -- Input 1 (RS1)
        i_data1     : in std_logic_vector(XLEN-1 downto 0);

        -- Input 2 (RS2)
        i_data2     : in std_logic_vector(XLEN-1 downto 0);

        -- Control signals
        i_opcode    : in std_logic_vector(6 downto 0);
        i_funct3    : in std_logic_vector(2 downto 0);
        i_funct7    : in std_logic_vector(6 downto 0);

        -- Output
        o_data      : out std_logic_vector(XLEN-1 downto 0)
    );
end entity riscy_alu;

architecture riscy_alu_rtl of riscy_alu is
    signal result       : std_logic_vector(XLEN-1 downto 0);

    -- XLEN+2 bit signed adder with carry in
    signal data1_ext    : signed(XLEN+1 downto 0);
    signal data2_ext    : signed(XLEN+1 downto 0);
    signal add_opa      : signed(XLEN+2 downto 0);
    signal add_opb      : signed(XLEN+2 downto 0);
    signal add_res      : signed(XLEN+2 downto 0);
    signal add_out      : std_logic_vector(XLEN-1 downto 0);
    signal sub          : std_logic;
    signal add_signed   : std_logic;
    signal negative     : std_logic;

    -- Left barrel shifter
    signal lshift_in    : signed(XLEN-1 downto 0);
    signal lshift_amnt  : natural range 0 to XLEN-1;
    signal lshift_out   : signed(XLEN-1 downto 0);

    -- Right barrel shifter
    signal rshift_in    : signed(XLEN downto 0);
    signal rshift_amnt  : natural range 0 to XLEN-1;
    signal rshift_out   : signed(XLEN downto 0);
    signal rshift_arith : std_logic; -- 0: logic right shift, 1: arithmetical right shift

    -- AND, OR and XOR
    signal and_out      : std_logic_vector(XLEN-1 downto 0);
    signal or_out       : std_logic_vector(XLEN-1 downto 0);
    signal xor_out      : std_logic_vector(XLEN-1 downto 0);
    
begin

    ------------------------------------------------------------------------------------------------
    ---                                  Adder/subtractor                                        ---
    ------------------------------------------------------------------------------------------------

    -- Sign extend input data when add_signed = '1'
    data1_ext(XLEN-1 downto 0) <= signed(i_data1);
    data1_ext(XLEN+0) <= i_data1(XLEN-1) and add_signed;
    data1_ext(XLEN+1) <= i_data1(XLEN-1) and add_signed;
    data2_ext(XLEN-1 downto 0) <= signed(i_data2);
    data2_ext(XLEN+0) <= i_data2(XLEN-1) and add_signed;
    data2_ext(XLEN+1) <= i_data2(XLEN-1) and add_signed;

    -- Conditionally invert the b operand and set carry in if subtracting
    add_opa(0) <= '1';
    add_opa(XLEN+2 downto 1) <= data1_ext;
    add_opb(0) <= sub;
    add_opb(XLEN+2 downto 1) <= not(data2_ext) when sub = '1' else data2_ext;

    -- Perform addition
    add_res <= add_opa + add_opb;
    add_out <= std_logic_vector(add_res(XLEN downto 1));
    negative <= add_res(XLEN+2);

    -- Sign/unsigned operation only affected by the SLT(U) and SLTI(U) instructions
    add_signed <= not(i_funct3(0));

    -- Subtraction is needed when performing SUB, SLT(U) and SLTI(U).
    sub <= 
        '1' when to_opcode(i_opcode) = OP_IMM and i_funct3(1) = '1' else  -- SLTI, SLTIU
        '1' when to_opcode(i_opcode) = OP     and i_funct3(1) = '1' else  -- SLT, SLTU
        '1' when to_opcode(i_opcode) = OP     and i_funct7(5) = '1' else  -- SUB
        '0';


    ------------------------------------------------------------------------------------------------
    ---                             Left and right barrel shifters                               ---
    ------------------------------------------------------------------------------------------------

    -- Left barrel shifter
    lshift_out <= shift_left(lshift_in, lshift_amnt);
    lshift_amnt <= to_integer(unsigned(i_data2(4 downto 0)));
    lshift_in <= signed(i_data1);
    
    -- Right barrel shifter
    rshift_out <= shift_right(rshift_in, rshift_amnt);
    rshift_amnt <= to_integer(unsigned(i_data2(4 downto 0)));
    rshift_in(XLEN-1 downto 0) <= signed(i_data1);
    rshift_arith <= i_funct7(5);
    rshift_in(XLEN) <= rshift_in(XLEN-1) when rshift_arith = '1' else '0';


    ------------------------------------------------------------------------------------------------
    ---                                         Misc                                             ---
    ------------------------------------------------------------------------------------------------

    -- AND, OR and XOR
    and_out <= i_data1 and i_data2;
    or_out <= i_data1 or i_data2;
    xor_out <= i_data1 xor i_data2;


    ------------------------------------------------------------------------------------------------
    ---                                Resulting multiplexer                                     ---
    ------------------------------------------------------------------------------------------------
    process(
        i_opcode, i_funct3, i_data2, add_out, xor_out, or_out, and_out, lshift_out, rshift_out,
        negative
    )
    begin
        case to_opcode(i_opcode) is
            when LUI =>
                result <= i_data2;
            when AUIPC =>
                result <= add_out;
            when JALR =>
                result <= add_out;
            when OP | OP_IMM =>
                case i_funct3 is
                    when "000" =>  -- ADD/SUB
                        result <= add_out;
                    when "010" =>  -- SLT(I)
                        result <= std_logic_vector(to_unsigned(0, XLEN-1) & negative);
                    when "011" =>  -- SLT(I)U
                        result <= std_logic_vector(to_unsigned(0, XLEN-1) & negative);
                    when "100" =>  -- XOR
                        result <= xor_out;
                    when "110" =>  -- OR
                        result <= or_out;
                    when "111" =>  -- AND
                        result <= and_out;
                    when "001" =>  -- SLL
                        result <= std_logic_vector(lshift_out);
                    when "101" =>  -- SR(L/A)
                        result <= std_logic_vector(rshift_out(XLEN-1 downto 0));
                    when others =>
                        result <= (others => '-');
                end case;
            when others =>
                result <= (others => '-');
        end case;
    end process;

    -- Output register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_data <= result;
        end if;
    end process;

end architecture;
