--
-- Riscy RISC-V branch tester
-- Author: Mikael Henriksson (2023)
--

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscy_conf.all;

entity riscy_branch_test is
    port(
        i_clk, i_rst    : in std_logic;

        -- Input 1 (RS1)
        i_opa           : in std_logic_vector(XLEN-1 downto 0);

        -- Input 2 (RS2)
        i_opb           : in std_logic_vector(XLEN-1 downto 0);

        -- Control signals
        i_opcode        : in std_logic_vector(6 downto 0);
        i_funct3        : in std_logic_vector(2 downto 0);
        i_funct7        : in std_logic_vector(6 downto 0);
        i_skip          : in std_logic;

        -- Output
        o_branch_take   : out std_logic
    );
end entity riscy_branch_test;

architecture riscy_branch_test_rtl of riscy_branch_test is
    signal opa_extended : signed(XLEN+1 downto 0);
    signal opb_extended : signed(XLEN+1 downto 0);
    signal difference   : signed(XLEN+1 downto 0); 
    signal sign_extend  : std_logic;
    signal branch_take  : std_logic;
begin

    -- Subtract operand B from A
    opa_extended(XLEN-1 downto 0) <= signed(i_opa);
    opb_extended(XLEN-1 downto 0) <= signed(i_opb);
    opa_extended(XLEN) <= opa_extended(XLEN-1) when sign_extend = '1' else '0';
    opb_extended(XLEN) <= opb_extended(XLEN-1) when sign_extend = '1' else '0';
    opa_extended(XLEN+1) <= opa_extended(XLEN);
    opb_extended(XLEN+1) <= opb_extended(XLEN);
    difference <= opa_extended-opb_extended;

    -- Sign extension during BEQ, BNE, BLT, BGE
    sign_extend <= '1' when to_opcode(i_opcode) = BRANCH and i_funct3(1) = '0' else '0';

    -- Branch take logic
    process(i_opcode, i_funct3, difference)
    begin
        if to_opcode(i_opcode) = BRANCH then
            case i_funct3 is
                when "000" =>  -- BEQ
                    branch_take <= '1' when difference = 0 else '0';
                when "001" =>  -- BNE
                    branch_take <= '0' when difference = 0 else '1';
                when "100" =>  -- BLT
                    branch_take <= difference(XLEN+1);
                when "101" =>  -- BGE
                    branch_take <= not(difference(XLEN+1));
                when "110" =>  -- BLTU
                    branch_take <= difference(XLEN+1);
                when "111" =>  -- BGEU
                    branch_take <= not(difference(XLEN+1));
                when others => 
                    branch_take <= '0';
            end case;
        elsif to_opcode(i_opcode) = JAL then
            branch_take <= '1';
        else
            branch_take <= '0';
        end if;
    end process;

    o_branch_take <= branch_take and not(i_skip);

end architecture riscy_branch_test_rtl;
