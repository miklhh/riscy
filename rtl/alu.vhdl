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

    -- 32 bit signed adder/subtractor
    signal add_opa      : signed(XLEN+1 downto 0);
    signal add_opb      : signed(XLEN+1 downto 0);
    signal add_res      : signed(XLEN+1 downto 0);
    signal sub          : std_logic;
    signal add_signed   : std_logic;

    -- Left barrel shifter
    signal lshift_in    : signed(XLEN-1 downto 0);
    signal lshift_amnt  : natural range 0 to 31;
    signal lshift_out   : signed(XLEN-1 downto 0);

    -- Right barrel shifter
    signal rshift_in    : signed(XLEN downto 0);
    signal rshift_amnt  : natural range 0 to 31;
    signal rshift_out   : signed(XLEN downto 0);
    signal rshift_arith : std_logic; -- 0: logic right shift, 1: arithmetical right shift

    -- AND, OR and XOR
    signal and_out      : std_logic_vector(XLEN-1 downto 0);
    signal or_out       : std_logic_vector(XLEN-1 downto 0);
    signal xor_out      : std_logic_vector(XLEN-1 downto 0);
    
begin

    -- 32 bit (un/)signed adder/subtractor
    add_res <= add_opa + add_opb;
    add_opa(0) <= '1';
    add_opa(32 downto 1) <= signed(i_data1);
    add_opa(33) <= add_opa(32) when add_signed = '1' else '0';
    add_opb(0) <= sub;
    add_opb(32 downto 1) <= signed(not(i_data2)) when sub = '1' else signed(i_data2);
    add_opb(33) <= add_opb(32) when add_signed = '1' else '0';
    add_signed <= '0';

    -- Subtraction is only needed when performing SUB.
    sub <= '1' when i_opcode = from_opcode(OP) and i_funct3 = "000" and i_funct7(5) = '1' else '0';

    -- Left barrel shifter
    lshift_out <= shift_left(lshift_in, lshift_amnt);
    lshift_amnt <= to_integer(unsigned(i_data2(4 downto 0)));
    lshift_in <= signed(i_data1);
    
    -- Right barrel shifter
    rshift_out <= shift_right(rshift_in, rshift_amnt);
    rshift_amnt <= to_integer(unsigned(i_data2(4 downto 0)));
    rshift_in(31 downto 0) <= signed(i_data1);
    rshift_arith <= i_funct7(5);
    rshift_in(32) <= rshift_arith;

    -- AND, OR and XOR
    and_out <= i_data1 and i_data2;
    or_out <= i_data1 or i_data2;
    xor_out <= i_data1 xor i_data2;

    -- Result multiplexer
    with i_funct3 select result <=
        std_logic_vector(add_res(32 downto 1))      when "000",  -- ADD/SUB
        xor_out                                     when "100",  -- XOR
        or_out                                      when "110",  -- OR
        and_out                                     when "111",  -- AND
        std_logic_vector(lshift_out)                when "001",  -- SLL
        std_logic_vector(rshift_out(31 downto 0))   when "101",  -- SR(L/A)
        (others => '-')                             when others;

    -- Output register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_opcode = "0110111" then  -- LUI
                o_data <= i_data2;
            else
                o_data <= result;
            end if;
        end if;
    end process;

end architecture;
